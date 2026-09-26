"""Adapters for live public data providers used by the app."""

from __future__ import annotations

import asyncio
import email.utils
import hashlib
import html
import math
import re
import time
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse
from xml.etree import ElementTree

import httpx

_CACHE: dict[str, tuple[float, Any]] = {}
_CACHE_SECONDS = {"news": 300, "prices": 300, "places": 600}
_GDELT_LOCK = asyncio.Lock()
_GDELT_LAST_REQUEST = 0.0


def _cache_get(key: str) -> Any | None:
    cached = _CACHE.get(key)
    if cached and cached[0] > time.monotonic():
        return cached[1]
    return None


def _cache_set(key: str, value: Any) -> Any:
    _CACHE[key] = (time.monotonic() + _CACHE_SECONDS[key.split(":", 1)[0]], value)
    return value


async def get_live_news() -> list[dict[str, Any]]:
    cached = _cache_get("news:recycling")
    if cached is not None:
        return cached
    try:
        global _GDELT_LAST_REQUEST
        async with _GDELT_LOCK:
            pause = 5.0 - (time.monotonic() - _GDELT_LAST_REQUEST)
            if pause > 0:
                await asyncio.sleep(pause)
            _GDELT_LAST_REQUEST = time.monotonic()
            params = {
                "query": '(recycling OR "e-waste" OR "plastic waste" OR "waste management") sourcecountry:IN',
                "mode": "artlist", "format": "json", "maxrecords": 30,
                "timespan": "30d", "sort": "datedesc",
            }
            async with httpx.AsyncClient(timeout=15.0, headers={"User-Agent": "KabadiwalaConnect/1.0"}) as client:
                response = await client.get("https://api.gdeltproject.org/api/v2/doc/doc", params=params)
                response.raise_for_status()
                payload = response.json()
        results: list[dict[str, Any]] = []
        for article in payload.get("articles", []):
            url, title = article.get("url"), (article.get("title") or "").strip()
            if not url or not title:
                continue
            try:
                published = datetime.strptime(article.get("seendate", ""), "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
            except ValueError:
                published = datetime.now(timezone.utc)
            results.append({
                "id": hashlib.sha256(url.encode("utf-8")).hexdigest()[:36],
                "title": title, "headline": title,
                "source": article.get("domain") or urlparse(url).netloc,
                "date": published.isoformat(), "published_at": published.isoformat(),
                "snippet": title, "body": title, "url": url, "dataSource": "GDELT",
            })
        if results:
            return _cache_set("news:recycling", results)
    except Exception:
        # Google News RSS is a second live source when GDELT throttles or is down.
        pass

    rss_params = {"q": "recycling OR e-waste OR plastic waste India", "hl": "en-IN", "gl": "IN", "ceid": "IN:en"}
    async with httpx.AsyncClient(timeout=15.0, headers={"User-Agent": "KabadiwalaConnect/1.0", "Accept": "application/rss+xml, application/xml"}) as client:
        response = await client.get("https://news.google.com/rss/search", params=rss_params)
        response.raise_for_status()
        root = ElementTree.fromstring(response.content)
    results = []
    for item in root.findall("./channel/item")[:30]:
        url, title = item.findtext("link"), (item.findtext("title") or "").strip()
        if not url or not title:
            continue
        try:
            published = email.utils.parsedate_to_datetime(item.findtext("pubDate") or "").astimezone(timezone.utc)
        except (TypeError, ValueError):
            published = datetime.now(timezone.utc)
        description = html.unescape(re.sub(r"<[^>]*>", " ", item.findtext("description") or title)).strip()
        results.append({
            "id": hashlib.sha256(url.encode("utf-8")).hexdigest()[:36],
            "title": title, "headline": title,
            "source": item.findtext("source") or urlparse(url).netloc,
            "date": published.isoformat(), "published_at": published.isoformat(),
            "snippet": description, "body": description, "url": url,
            "dataSource": "Google News RSS",
        })
    return _cache_set("news:recycling", results)


async def get_live_metal_benchmarks() -> list[dict[str, Any]]:
    cached = _cache_get("prices:metals")
    if cached is not None:
        return cached
    metals = ["copper", "aluminum", "zinc", "nickel", "lead", "tin"]
    async with httpx.AsyncClient(timeout=15.0, headers={"User-Agent": "KabadiwalaConnect/1.0", "Accept": "application/json"}) as client:
        responses = await asyncio.gather(
            *(client.get(f"https://croncopia.com/api/metals/{metal}.json") for metal in metals),
            client.get("https://api.frankfurter.dev/v2/rate/usd/inr"),
            return_exceptions=True,
        )
    fx_response = responses[-1]
    if isinstance(fx_response, Exception):
        raise fx_response
    fx_response.raise_for_status()
    fx_rate = float(fx_response.json()["rate"])
    labels = {"copper": "Copper", "aluminum": "Aluminium", "zinc": "Zinc", "nickel": "Nickel", "lead": "Lead", "tin": "Tin"}
    fetched_at = datetime.now(timezone.utc).isoformat()
    results: list[dict[str, Any]] = []
    for key, response in zip(metals, responses[:-1]):
        if isinstance(response, Exception) or response.status_code != 200:
            continue
        quote = response.json()
        price_data = quote.get("price")
        if not isinstance(price_data, dict) or price_data.get("kilogram") is None:
            continue
        price = float(price_data["kilogram"])
        inr_per_kg = price * fx_rate
        label = labels[key]
        results.append({
            "id": f"metalmarket-{key}", "materialCategory": label,
            "materialSubCategory": "Raw metal benchmark", "location": "International benchmark",
            "date": quote.get("timestamp") or fetched_at,
            "price": round(inr_per_kg, 2), "currency": "INR", "unit": "per_kg",
            "nativePrice": price, "nativeUnit": "USD/kg",
            "sourceCount": quote.get("sources"),
            "source": "Croncopia aggregated metal benchmarks + Frankfurter USD/INR",
            "sourceUrl": "https://croncopia.com/docs/commodity-source",
            "dataType": "global_raw_metal_benchmark",
            "notice": "Reference benchmark only; not a local scrap offer or recycler quote.",
        })
    if not results:
        raise ValueError("The metal benchmark API returned no supported metal quotes")
    return _cache_set("prices:metals", results)


def _distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    earth_radius_km = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi, dlambda = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return earth_radius_km * 2 * math.asin(math.sqrt(a))


async def get_nearby_recycling_points(lat: float, lng: float, radius_km: float) -> list[dict[str, Any]]:
    rounded_lat, rounded_lng = round(lat, 2), round(lng, 2)
    cache_key = f"places:{rounded_lat}:{rounded_lng}:{radius_km:.1f}"
    cached = _cache_get(cache_key)
    if cached is not None:
        return [
            {**place, "distance_km": round(_distance_km(lat, lng, place["latitude"], place["longitude"]), 1)}
            for place in cached
        ]
    radius_m = int(radius_km * 1000)
    query = (
        f"[out:json][timeout:20];("
        f"nwr(around:{radius_m},{rounded_lat},{rounded_lng})[\"amenity\"=\"recycling\"];"
        f"nwr(around:{radius_m},{rounded_lat},{rounded_lng})[\"shop\"=\"scrap_yard\"];"
        f"nwr(around:{radius_m},{rounded_lat},{rounded_lng})[\"landuse\"=\"recycling\"];);out center tags 80;"
    )
    async with httpx.AsyncClient(timeout=25.0, headers={"User-Agent": "KabadiwalaConnect/1.0 (nearby recycling points)", "Accept": "application/json"}) as client:
        response = await client.get("https://overpass-api.de/api/interpreter", params={"data": query})
        response.raise_for_status()
        payload = response.json()
    results: list[dict[str, Any]] = []
    for item in payload.get("elements", []):
        tags = item.get("tags", {})
        point_lat = item.get("lat", (item.get("center") or {}).get("lat"))
        point_lng = item.get("lon", (item.get("center") or {}).get("lon"))
        if point_lat is None or point_lng is None:
            continue
        point_lat, point_lng = float(point_lat), float(point_lng)
        distance = _distance_km(lat, lng, point_lat, point_lng)
        if distance > radius_km:
            continue
        osm_type, osm_id = item.get("type", "node"), item.get("id")
        results.append({
            "id": f"{osm_type}/{osm_id}",
            "name": tags.get("name") or tags.get("operator") or "Recycling point",
            "type": tags.get("shop") or tags.get("amenity") or tags.get("landuse") or "recycling",
            "materials": tags.get("recycling:materials") or tags.get("recycling_type") or "Not specified on map",
            "address": " ".join(filter(None, [tags.get("addr:housenumber"), tags.get("addr:street"), tags.get("addr:suburb"), tags.get("addr:city")])),
            "latitude": point_lat, "longitude": point_lng, "distance_km": round(distance, 1),
            "source": "OpenStreetMap", "authorizationStatus": "Not verified",
            "url": f"https://www.openstreetmap.org/{osm_type}/{osm_id}",
        })
    results.sort(key=lambda item: item["distance_km"])
    _cache_set(cache_key, results)
    return results
