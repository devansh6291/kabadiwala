import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_colors.dart';
import '../app_strings.dart';
import '../models/collector_store.dart';
import '../services/location_service.dart';
import '../services/firebase_service.dart';

/// One-time onboarding/login screen with Real Firebase OTP.
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
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String _language = 'hi';
  bool _locating = true;
  double? _latitude;
  double? _longitude;
  String _locationLabel = 'Detecting your location...';

  bool _saving = false;
  bool _otpSent = false;
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _autoDetectLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _autoDetectLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (position == null) {
      setState(() {
        _locating = false;
        _locationLabel = 'Location unavailable — you can add it later.';
      });
      return;
    }

    _latitude = position.latitude;
    _longitude = position.longitude;

    try {
      final placemarks = await Geocoding()
          .placemarkFromCoordinates(position.latitude, position.longitude);
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
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _locating = false;
      _locationLabel =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    });
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Firebase expects phone numbers with country codes. Defaulting to India (+91)
    final phone = '+91${_phoneController.text.trim()}';

    await FirebaseService().sendOtp(
      phoneNumber: phone,
      onCodeSent: (String verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP Sent!')),
        );
      },
      onVerificationFailed: (FirebaseAuthException error) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification Failed: ${error.message}')),
        );
      },
      onAutoVerified: (PhoneAuthCredential credential) async {
        // Auto-resolution for Android
        await _finalizeLogin(credential);
      },
    );
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await _finalizeLogin(credential);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Please try again.')),
      );
    }
  }

  Future<void> _finalizeLogin(PhoneAuthCredential credential) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);

      final profile =
          CollectorStore.getOrCreate(phoneNumber: _phoneController.text.trim());
      profile.name = _nameController.text.trim();
      profile.age = int.tryParse(_ageController.text.trim());
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
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
                if (!_otpSent) ...[
                  // --- PROFILE INPUT STAGE ---
                  const Text('Full name',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    // Letters and spaces only — no digits, no symbols.
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
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
                    // Digits only, capped at 3 characters (max realistic age).
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: _fieldDecoration('e.g. 34'),
                    validator: (v) {
                      final age = int.tryParse(v?.trim() ?? '');
                      if (age == null || age < 14 || age > 100)
                        return 'Enter a valid age';
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
                    // Digits only — the +91 prefix below is display-only and
                    // is never part of this controller's text, so this
                    // maxLength genuinely means 10 real phone digits.
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration:
                        _fieldDecoration('10-digit number (OTP will be sent)')
                            .copyWith(
                      counterText: '',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(14.0),
                        child: Text('+91 ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
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
                      onPressed: _saving ? null : _sendOtp,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Send OTP',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else ...[
                  // --- OTP VERIFICATION STAGE ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryGreen),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'OTP sent to +91 ${_phoneController.text}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          // Digits only for the OTP code too.
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(
                              fontSize: 24,
                              letterSpacing: 8,
                              fontWeight: FontWeight.bold),
                          decoration: _fieldDecoration('------')
                              .copyWith(counterText: ''),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _saving ? null : _verifyOtp,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : const Text('Verify & Login',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _saving ? null : () => setState(() => _otpSent = false),
                    child: const Text('Change Phone Number',
                        style: TextStyle(color: Colors.black54)),
                  ),
                ],
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
          borderSide: const BorderSide(color: AppColors.lightGreen)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightGreen)),
    );
  }
}
