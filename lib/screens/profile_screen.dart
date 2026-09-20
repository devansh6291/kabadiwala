import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_strings.dart';
import '../models/collector.dart';
import '../models/collector_store.dart';
import '../models/lot_store.dart';
import 'lot_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late CollectorProfile _profile = CollectorStore.getOrCreate();
  late final TextEditingController _nameController =
      TextEditingController(text: _profile.name);
  late final TextEditingController _ageController =
      TextEditingController(text: _profile.age?.toString() ?? '');
  late final TextEditingController _locationController =
      TextEditingController(text: _profile.operatingLocation);
  late final TextEditingController _phoneController =
      TextEditingController(text: _profile.phoneNumber);
  bool _saving = false;
  bool _showFullAadhar = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    _profile.name = _nameController.text.trim();
    _profile.age = int.tryParse(_ageController.text.trim());
    _profile.operatingLocation = _locationController.text.trim();
    _profile.phoneNumber = _phoneController.text.trim();
    await CollectorStore.save(_profile);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lots = LotStore.getAllLots();
    final liveEstimatedTotal =
        lots.fold<double>(0, (sum, l) => sum + (l.estimatedValue ?? 0));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionCard(
            title: 'Full name',
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Age',
            child: TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Aadhaar number',
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _showFullAadhar
                        ? _profile.aadharNumber
                        : _profile.maskedAadhar,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 15),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _showFullAadhar = !_showFullAadhar),
                  child: Text(_showFullAadhar ? 'Hide' : 'Show'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Collector ID',
            child: SelectableText(_profile.collectorId,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Preferred language',
            child: DropdownButton<String>(
              value: AppStrings.languageNames
                      .containsKey(_profile.preferredLanguage)
                  ? _profile.preferredLanguage
                  : AppStrings.languageNames.keys.first,
              isExpanded: true,
              underline: const SizedBox(),
              items: AppStrings.languageNames.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _profile.preferredLanguage = value);
              },
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Operating area / beat',
            child: TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Auto-detected — edit if needed',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Phone number',
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                counterText: '',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Own transport',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _profile.hasOwnLogistics,
              activeColor: AppColors.primaryGreen,
              title: const Text('I also aggregate for other nearby collectors'),
              subtitle: const Text(
                  'Turns on pooling routing to you as a local hub',
                  style: TextStyle(fontSize: 12)),
              onChanged: (value) =>
                  setState(() => _profile.hasOwnLogistics = value),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text('Save Profile'),
            ),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Earnings ledger',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primaryGreen)),
          const SizedBox(height: 8),
          _sectionCard(
            title: 'Settled transactions',
            child: Text(
              '${_profile.transactionHistoryIds.length} completed · ₹${_profile.totalEarnings.toStringAsFixed(0)} total\n'
              '(updates once the transaction/settlement flow is built)',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Lots collected so far (pending settlement)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lots.length} lots · ~₹${liveEstimatedTotal.toStringAsFixed(0)} estimated',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LotHistoryScreen()));
                  },
                  child: const Text('View all lots'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
