import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

import '../app_colors.dart';
import '../app_strings.dart';
import '../models/collector.dart';
import '../models/collector_store.dart';
import '../services/location_service.dart';

/// One-time onboarding/login screen. Shown only when
/// CollectorStore.isOnboarded() is false — see main.dart. Once completed,
/// the app never shows this again on later launches.
class LoginScreen extends StatefulWidget {
  final ValueChanged<String> onComplete;

  const LoginScreen({super.key, required this.onComplete});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _aadharController = TextEditingController();
  final _phoneController = TextEditingController();
  String _language = 'hi';

  bool _locating = true;
  double? _latitude;
  double? _longitude;
  String _locationLabel = 'Detecting your location...';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _autoDetectLocation(); // no button — happens automatically on load
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _aadharController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _autoDetectLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (position == null) {
      setState(() {
        _locating = false;
        _locationLabel =
            'Location unavailable — you can add it later from your profile.';
      });
      return;
    }

    _latitude = position.latitude;
    _longitude = position.longitude;

    try {
      final geocodingService = Geocoding();
      final placemarks = await geocodingService.placemarkFromCoordinates(
          position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.subLocality != null && p.subLocality!.isNotEmpty)
            p.subLocality!,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
        ];
        final label = parts.join(', ');
        if (!mounted) return;
        setState(() {
          _locating = false;
          _locationLabel = label.isNotEmpty
              ? label
              : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });
        return;
      }
    } catch (_) {
      // Reverse geocoding failed (no network/offline) — fall back to raw coordinates.
    }

    if (!mounted) return;
    setState(() {
      _locating = false;
      _locationLabel =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final profile = CollectorStore.getOrCreate();
    profile.name = _nameController.text.trim();
    profile.age = int.tryParse(_ageController.text.trim());
    profile.aadharNumber = _aadharController.text.trim();
    profile.phoneNumber = _phoneController.text.trim();
    profile.preferredLanguage = _language;
    profile.operatingLocation = _locationLabel;
    profile.latitude = _latitude;
    profile.longitude = _longitude;
    profile.isOnboarded = true;

    await CollectorStore.save(profile);

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onComplete(_language);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.recycling,
                    color: AppColors.primaryGreen, size: 56),
                const SizedBox(height: 12),
                const Text(
                  'Welcome to Kabadiwala Connect',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Let\'s set up your profile — just once.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 28),
                const Text('Full name',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: _fieldDecoration('e.g. Ramesh Kumar'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                const Text('Age',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration('e.g. 34'),
                  validator: (v) {
                    final age = int.tryParse(v?.trim() ?? '');
                    if (age == null || age < 14 || age > 100)
                      return 'Enter a valid age';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('Aadhaar number',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _aadharController,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: _fieldDecoration('12-digit Aadhaar number')
                      .copyWith(counterText: ''),
                  validator: (v) {
                    final digits = (v ?? '').trim();
                    if (digits.length != 12 || int.tryParse(digits) == null) {
                      return 'Enter a valid 12-digit Aadhaar number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('Phone number',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration:
                      _fieldDecoration('For OTP login & signing manifests')
                          .copyWith(counterText: ''),
                  validator: (v) {
                    final digits = (v ?? '').trim();
                    if (digits.length != 10 || int.tryParse(digits) == null) {
                      return 'Enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('Preferred language',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.lightGreen),
                  ),
                  child: DropdownButton<String>(
                    value: AppStrings.languageNames.containsKey(_language)
                        ? _language
                        : AppStrings.languageNames.keys.first,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: AppStrings.languageNames.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _language = value);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      _locating ? Icons.my_location : Icons.location_on,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locating
                            ? _locationLabel
                            : 'Area detected: $_locationLabel',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54),
                      ),
                    ),
                    if (_locating)
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Continue',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lightGreen)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lightGreen)),
    );
  }
}
