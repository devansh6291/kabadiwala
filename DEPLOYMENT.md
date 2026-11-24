# Deployment

The Flutter web app is configured for Firebase Hosting. The default
`render.yaml` targets a $0 hobby deployment using Render's free API service
and a hosted PostgreSQL database. The backend accepts PostgreSQL connection
URLs through `KABADIWALA_DATABASE_URL`.

## Free backend setup

1. Create a Supabase project on its free plan and wait for its database to
   finish provisioning. In Supabase, open **Connect** and choose the
   **Session pooler** connection string. Render services use IPv4, so use the
   session pooler rather than the direct database connection. The session
   pooler uses port `5432`; do not use the transaction pooler's port `6543`.
2. The Git repository must be available to your Render account. If you do not
   own the source repository, fork it to your GitHub account first. In Render,
   create a Blueprint from your fork using `render.yaml`.
3. In Render, open the API service's **Environment** settings and set
   `KABADIWALA_DATABASE_URL` to the Supabase session-pooler URI. Ensure it has
   `?sslmode=require` (append it if the URI has no query string; otherwise add
   `&sslmode=require`). Save the setting and redeploy. The backend converts
   PostgreSQL URLs to its async driver and enables TLS. Do not put database
   credentials in source code; URL-encode special characters in the password.
4. Wait for the API service to deploy, then copy its HTTPS URL. The app creates
   its tables on startup. A new Supabase database starts empty; data in the old
   Aiven database is not copied automatically. Export any data you need before
   switching providers.

Free-tier limits apply: Render spins its free web service down after 15 minutes
without traffic (the next request may take about a minute to wake it). Supabase
Free currently includes 500 MB of database storage and may pause projects with
low database activity over a 7-day period; paused projects can be restored from
the Supabase dashboard. The Render free configuration disables image
classification because the model's memory needs are not a reliable fit for the
free service. [Render free limits](https://render.com/docs/free) ·
[Supabase pricing](https://supabase.com/pricing) ·
[Supabase project pausing](https://supabase.com/docs/guides/platform/free-project-pausing)

### Demo sign-in with Firebase test numbers

The login screen currently expects an Indian mobile number: it adds `+91` to
the 10 digits entered in the app. For a demo, configure a Firebase test number
so Firebase returns a fixed code without sending an SMS:

1. In Firebase Console, open **Authentication → Sign-in method** and enable
   **Phone**.
2. In **Phone numbers for testing**, add a fictional test number in `+91`
   format and choose a six-digit test code. Do not use a real person's number.
3. In the app, enter the same number's 10 digits (without `+91`), then enter
   the fixed code you configured.

Only numbers configured in that list can use the fixed demo code. Keep the
number and code private, and remove them when the demo ends. Real phone
verification uses SMS and may require a billing account. [Firebase phone-auth
testing](https://firebase.google.com/docs/auth/flutter/phone-auth) ·
[Firebase billing and phone-auth requirements](https://firebase.google.com/docs/auth/faq-and-troubleshooting)

## Firebase Hosting

From the repository root, build the web app with the deployed API URL and then
deploy the static output. Firebase Hosting has a no-cost Spark option within
its published quotas.

```powershell
flutter build web --dart-define=API_BASE_URL=https://YOUR-API.onrender.com
firebase deploy --only hosting
```

The API allows the project's default `web.app` and `firebaseapp.com` domains,
Firebase preview channels, and localhost Flutter web development. If the site
uses a custom domain, set `CORS_ALLOW_ORIGINS` in Render to include its exact
origin (scheme and hostname, no trailing slash); separate multiple origins
with commas.

## Android and other platforms

Builds that call the hosted API must use its HTTPS URL with
`--dart-define=API_BASE_URL=...`.

- **Android private install:** `flutter build apk --release`. The current
  Android release configuration uses the debug signing key, so this is for
  private testing only and is not suitable for Google Play.
- **Google Play:** set a permanent, unique Android application ID, register
  that ID in Firebase, create and securely store an upload keystore, configure
  release signing, and build with `flutter build appbundle`. The current ID is
  still `com.example.kabadiwala_connect`.
- **iOS and macOS:** build and sign on macOS with Xcode and the corresponding
  Apple Developer account.
- **Windows and Linux:** build on the matching operating system; each platform
  uses its own installer or package format.

Flutter's official platform deployment guides cover the build and signing
steps for [Android](https://docs.flutter.dev/deployment/android),
[iOS](https://docs.flutter.dev/deployment/ios),
[web](https://docs.flutter.dev/deployment/web), and
[desktop](https://docs.flutter.dev/deployment).

## Database data

The hosted database starts empty. Import only the records you want available
in the hosted app after the database is running; local database credentials
and data are not copied by the Blueprint.
