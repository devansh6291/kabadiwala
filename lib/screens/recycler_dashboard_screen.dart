import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_colors.dart';
import '../models/lot.dart';
import '../services/api_client.dart';
import 'form6_signing_screen.dart';

class RecyclerDashboardScreen extends StatefulWidget {
  final String recyclerId;
  final String languageCode;
  final VoidCallback onSignOut;

  const RecyclerDashboardScreen({
    super.key,
    required this.recyclerId,
    required this.languageCode,
    required this.onSignOut,
  });

  @override
  State<RecyclerDashboardScreen> createState() => _RecyclerDashboardScreenState();
}

class _RecyclerDashboardScreenState extends State<RecyclerDashboardScreen> {
  int _tab = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _dashboard = {};

  static const _fallbackProfile = <String, dynamic>{
    'recyclerId': 'sample-recycler-indore-01',
    'name': 'GreenLoop Materials Recovery',
    'facilityLat': 22.7196,
    'facilityLng': 75.8577,
    'materialsAccepted': ['PCB', 'CRT', 'Cables', 'Battery', 'Motor', 'MixedPlastics', 'OtherEwaste'],
    'authorizationNumber': 'DEMO-CCA-2026-014',
    'authorizationStatus': 'sample',
    'contactDetails': 'Contact details unavailable in presentation profile',
    'offeredRates': {'PCB': 180, 'CRT': 8, 'Cables': 90, 'Battery': 40, 'Motor': 60, 'MixedPlastics': 15},
    'pickupAvailability': 'Scheduled',
    'serviceAreaRadiusKm': 50,
  };

  static const _fallbackRequests = <Map<String, dynamic>>[
    {
      'requestId': 'demo-request-1001',
      'collectorId': 'demo-collector-1001',
      'collectorName': 'Ramesh Kumar',
      'collectorPhone': '+91 90000 00001',
      'collectorLocation': 'Indore, Madhya Pradesh',
      'lotId': 'demo-lot-lcd-1001',
      'category': 'OtherEwaste',
      'subCategory': 'LCD Panel',
      'approxWeightKg': 14.5,
      'estimatedValue': 1160,
      'quotedPrice': 1015,
      'lotLatitude': 22.7241,
      'lotLongitude': 75.8622,
      'createdAt': '2026-09-27T08:30:00Z',
      'status': 'requested',
      'photoRefs': [],
      'manifestId': 'DEMO-F6-1001',
      'isSampleData': true,
    },
    {
      'requestId': 'demo-request-1002',
      'collectorId': 'demo-collector-1002',
      'collectorName': 'Savitri Devi',
      'collectorPhone': '+91 90000 00002',
      'collectorLocation': 'Vijay Nagar, Indore',
      'lotId': 'demo-lot-pcb-1002',
      'category': 'PCB',
      'subCategory': 'Motherboard',
      'approxWeightKg': 8.0,
      'estimatedValue': 1440,
      'quotedPrice': 1280,
      'lotLatitude': 22.7520,
      'lotLongitude': 75.8937,
      'createdAt': '2026-09-27T09:10:00Z',
      'status': 'requested',
      'photoRefs': [],
      'manifestId': null,
      'isSampleData': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await ApiClient().dio.get('/recycler-dashboard/${widget.recyclerId}');
      if (!mounted) return;
      setState(() { _dashboard = Map<String, dynamic>.from(response.data); _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dashboard = {
          'profile': _fallbackProfile,
          'requests': _fallbackRequests,
          'manifests': [
            {
              'manifestId': 'DEMO-F6-1001',
              'lotReferenceId': 'demo-lot-lcd-1001',
              'senderName': 'Ramesh Kumar',
              'materialType': 'OtherEwaste · LCD Panel',
              'quantity': 14.5,
              'destinationRecyclerId': widget.recyclerId,
              'status': 'Draft for presentation',
              'sampleData': true,
            },
          ],
          'isSampleData': true,
        };
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _requests =>
      List<Map<String, dynamic>>.from(_dashboard['requests'] ?? const []);
  List<Map<String, dynamic>> get _manifests =>
      List<Map<String, dynamic>>.from(_dashboard['manifests'] ?? const []);
  Map<String, dynamic> get _profile =>
      Map<String, dynamic>.from(_dashboard['profile'] ?? _fallbackProfile);

  Future<void> _decide(Map<String, dynamic> request, String decision) async {
    final requestId = request['requestId']?.toString() ?? '';
    var saved = false;
    try {
      final response = await ApiClient().dio.patch(
        '/logistics-requests/$requestId',
        queryParameters: {'recycler_id': widget.recyclerId},
        data: {'status': decision},
      );
      saved = response.statusCode == 200;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      final updated = _requests.map((entry) => entry['requestId'] == requestId
          ? {...entry, 'status': decision}
          : entry).toList();
      _dashboard = {..._dashboard, 'requests': updated};
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved
          ? 'Request ${decision == 'accepted' ? 'accepted' : 'declined'} and saved.'
          : 'Request updated for this session; server is unavailable.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final destinations = const ['Logistics', 'My recycler profile', 'Form-6'];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(destinations[_tab]),
        actions: [
          IconButton(onPressed: _loadDashboard, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: Text(widget.recyclerId, style: const TextStyle(fontSize: 10))),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _tab, children: [
              _requestsView(),
              _profileView(),
              _manifestView(),
            ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.factory_outlined), selectedIcon: Icon(Icons.factory), label: 'My profile'),
          NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Form-6'),
        ],
      ),
    );
  }

  Widget _sampleBanner() => const Card(
        color: Color(0xFFFFF3CD),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Presentation records are clearly marked. Decisions made on this screen are saved when the backend is connected.'),
        ),
      );

  Widget _requestsView() {
    final requests = _requests;
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sampleBanner(),
          Text('${requests.length} logistics request(s)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (requests.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No logistics requests are available yet.'))),
          ...requests.map(_requestCard),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final status = (request['status'] ?? 'requested').toString();
    final lat = _nullableNumber(request['lotLatitude'] ?? request['lot_latitude']);
    final lng = _nullableNumber(request['lotLongitude'] ?? request['lot_longitude']);
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(child: Icon(Icons.person_outline)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(request['collectorName']?.toString() ?? 'Collector', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${request['collectorLocation'] ?? 'Location not provided'} · ${request['collectorPhone'] ?? ''}', style: const TextStyle(fontSize: 12)),
            ])),
            Chip(label: Text(status)),
          ]),
          const Divider(height: 22),
          Text('${request['category'] ?? ''} · ${request['subCategory'] ?? request['sub_category'] ?? 'Material lot'}', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('Lot ${request['lotId'] ?? request['lot_id'] ?? '—'} · ${_number(request['approxWeightKg'] ?? request['approx_weight_kg']).toStringAsFixed(1)} kg'),
          Text('Indicative value ₹${_number(request['estimatedValue'] ?? request['estimated_value']).toStringAsFixed(0)} · requested offer ₹${_number(request['quotedPrice'] ?? request['quoted_price']).toStringAsFixed(0)}'),
          Text('Requested ${request['createdAt'] ?? request['created_at'] ?? 'recently'}'),
          if (request['isSampleData'] == true || request['is_sample_data'] == true)
            const Padding(padding: EdgeInsets.only(top: 6), child: Text('Sample request · no real pickup is created', style: TextStyle(color: AppColors.pending, fontSize: 12))),
          Wrap(spacing: 8, children: [
            TextButton.icon(
              onPressed: lat == null || lng == null ? null : () => launchUrl(Uri.parse('https://maps.google.com/?q=${lat.toDouble()},${lng.toDouble()}'), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.map_outlined), label: const Text('Lot location'),
            ),
            if (request['manifestId'] != null || request['manifest_id'] != null)
              TextButton.icon(onPressed: () => setState(() => _tab = 2), icon: const Icon(Icons.description_outlined), label: const Text('View Form-6')),
          ]),
          if (status == 'requested')
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _decide(request, 'declined'), icon: const Icon(Icons.close), label: const Text('Decline'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(onPressed: () => _decide(request, 'accepted'), icon: const Icon(Icons.check), label: const Text('Accept logistics'))),
            ]),
          if (status == 'accepted')
            FilledButton.icon(onPressed: () => _openManifestForRequest(request), icon: const Icon(Icons.draw), label: const Text('Continue handover / Form-6')),
        ]),
      ),
    );
  }

  Widget _profileView() {
    final profile = _profile;
    final lat = (profile['facilityLat'] ?? profile['facility_location_lat'] ?? 22.7196) as num;
    final lng = (profile['facilityLng'] ?? profile['facility_location_lng'] ?? 75.8577) as num;
    final materials = List<String>.from(profile['materialsAccepted'] ?? profile['materials_accepted'] ?? const []);
    return ListView(padding: const EdgeInsets.all(16), children: [
      _sampleBanner(),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleAvatar(radius: 30, child: Icon(Icons.factory, size: 32)),
        const SizedBox(height: 12),
        Text(profile['name']?.toString() ?? 'Recycler', style: Theme.of(context).textTheme.titleLarge),
        Text('Recycler ID · ${profile['recyclerId'] ?? profile['recycler_id'] ?? widget.recyclerId}'),
        Text('Authorization · ${profile['authorizationNumber'] ?? profile['authorization_number'] ?? 'Not recorded'} · ${profile['authorizationStatus'] ?? profile['authorization_status'] ?? 'sample'}'),
        Text('Contact · ${profile['contactDetails'] ?? profile['contact_details'] ?? 'Not recorded'}'),
        Text('Pickup · ${profile['pickupAvailability'] ?? profile['pickup_availability'] ?? 'Scheduled'} · service radius ${_number(profile['serviceAreaRadiusKm'] ?? profile['service_area_radius_km'] ?? 50).toStringAsFixed(0)} km'),
        const SizedBox(height: 8),
        const Text('Materials accepted', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 6, children: materials.map((m) => Chip(label: Text(m))).toList()),
        const SizedBox(height: 8),
        Text('Facility · ${lat.toDouble().toStringAsFixed(5)}, ${lng.toDouble().toStringAsFixed(5)}'),
        TextButton.icon(onPressed: () => launchUrl(Uri.parse('https://maps.google.com/?q=${lat.toDouble()},${lng.toDouble()}'), mode: LaunchMode.externalApplication), icon: const Icon(Icons.map), label: const Text('Open recycler location')),
      ]))),
      const Text('Offers (₹/kg)', style: TextStyle(fontWeight: FontWeight.bold)),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Text((profile['offeredRates'] ?? profile['offered_rates'] ?? const {}).entries.map((e) => '${e.key}: ₹${e.value}/kg').join('  ·  ')))),
    ]);
  }

  Widget _manifestView() {
    final manifests = _manifests;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _sampleBanner(),
      Text('Handover manifests', style: Theme.of(context).textTheme.titleLarge),
      if (manifests.isEmpty) const Padding(padding: EdgeInsets.all(18), child: Text('No Form-6 manifests are linked to this recycler yet.')),
      ...manifests.map((manifest) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reference ${manifest['manifestId'] ?? manifest['manifest_id'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Collector / sender · ${manifest['senderName'] ?? manifest['sender_name'] ?? 'Not recorded'}'),
        Text('Material · ${manifest['materialType'] ?? manifest['material_type'] ?? '—'} · ${_number(manifest['quantity']).toStringAsFixed(1)} kg'),
        Text('Lot · ${manifest['lotReferenceId'] ?? manifest['lot_reference_id'] ?? '—'}'),
        Text('Status · ${manifest['status'] ?? 'Recorded'}'),
        if (manifest['sampleData'] == true || manifest['isSampleData'] == true) const Text('Sample manifest · signatures shown are illustrative', style: TextStyle(color: AppColors.pending)),
        FilledButton.icon(onPressed: () => _openManifest(manifest), icon: const Icon(Icons.picture_as_pdf), label: const Text('Open and generate Form-6 PDF')),
      ])))),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse(_pdfFillerUrl), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new), label: const Text('Open form on pdfFiller')),
    ]);
  }

  static const _pdfFillerUrl = 'https://www.pdffiller.com/409045148-FORM-6-E-waste-Rules-2016pdf-form-6-e-waste-';

  Future<void> _openManifestForRequest(Map<String, dynamic> request) => _openManifest({
    'manifestId': request['manifestId'] ?? 'F6-${request['requestId']}',
    'lotReferenceId': request['lotId'],
    'senderName': request['collectorName'],
    'materialType': '${request['category']} · ${request['subCategory']}',
    'quantity': request['approxWeightKg'],
    'sampleData': request['isSampleData'] == true,
  });

  Future<void> _openManifest(Map<String, dynamic> manifest) async {
    final request = _requests.firstWhere(
      (item) => (item['lotId'] ?? item['lot_id']) == (manifest['lotReferenceId'] ?? manifest['lot_reference_id']),
      orElse: () => _fallbackRequests.first,
    );
    final lot = Lot(
      id: (manifest['lotReferenceId'] ?? manifest['lot_reference_id'] ?? request['lotId']).toString(),
      category: (manifest['materialType'] ?? manifest['material_type'] ?? request['category']).toString().split(' · ').first,
      subCategory: (request['subCategory'] ?? request['sub_category'])?.toString(),
      approxWeightKg: _number(manifest['quantity'] ?? request['approxWeightKg']),
      photoPaths: List<String>.from(request['photoRefs'] ?? request['photo_refs'] ?? const []),
      estimatedValue: _number(request['estimatedValue'] ?? request['estimated_value']),
      createdAt: DateTime.tryParse((request['createdAt'] ?? request['created_at'] ?? '').toString()) ?? DateTime.now(),
      latitude: _number(request['lotLatitude'] ?? request['lot_latitude']) == 0 ? null : _number(request['lotLatitude'] ?? request['lot_latitude']),
      longitude: _number(request['lotLongitude'] ?? request['lot_longitude']) == 0 ? null : _number(request['lotLongitude'] ?? request['lot_longitude']),
    );
    await Navigator.push(context, MaterialPageRoute(builder: (_) => Form6SigningScreen(
      lot: lot,
      recyclerId: widget.recyclerId,
      initialManifestData: manifest,
    )));
    if (mounted) await _loadDashboard();
  }

  double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  num? _nullableNumber(dynamic value) => value is num ? value : num.tryParse('$value');
}
