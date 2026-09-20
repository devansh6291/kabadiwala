import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_strings.dart';
import '../models/lot_store.dart';
import 'create_lot_screen.dart';
import 'lot_history_screen.dart';
import 'profile_screen.dart';
import '../services/api_classifier_service.dart';
import '../models/collector_store.dart';

class HomeScreen extends StatefulWidget {
  final String currentLanguage;
  final ValueChanged<String?> onLanguageChanged;

  const HomeScreen({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _greetingKey() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'greetingMorning';
    if (hour < 17) return 'greetingAfternoon';
    return 'greetingEvening';
  }

  Future<void> _openAndRefresh(Widget screen) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => screen));
    if (mounted) setState(() {}); // refresh stats after returning
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.currentLanguage;
    final lots = LotStore.getAllLots();
    final totalValue = lots.fold<double>(
      0,
      (sum, lot) => sum + (lot.estimatedValue ?? 0),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.get('appTitle', lang)),
        actions: [
          DropdownButton<String>(
            value: lang,
            dropdownColor: AppColors.primaryGreen,
            underline: const SizedBox(),
            icon: const Icon(Icons.language, color: Colors.white),
            onChanged: widget.onLanguageChanged,
            items: AppStrings.languageNames.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value,
                    style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _welcomeCard(lang, CollectorStore.getOrCreate().name),
            const SizedBox(height: 20),
            _statsRow(lang, lots.length, totalValue),
            const SizedBox(height: 24),
            _actionCard(
              icon: Icons.add_a_photo,
              title: AppStrings.get('newCollection', lang),
              subtitle: AppStrings.get('newCollectionSub', lang),
              color: AppColors.primaryGreen,
              onTap: () => _openAndRefresh(CreateLotScreen(
                classifierService:
                    ApiClassifierService(baseUrl: 'http://192.168.98.41:8000'),
              )),
            ),
            const SizedBox(height: 14),
            _actionCard(
              icon: Icons.history,
              title: AppStrings.get('myLots', lang),
              subtitle: AppStrings.get('myLotsSub', lang),
              color: AppColors.primaryYellow,
              onTap: () => _openAndRefresh(const LotHistoryScreen()),
            ),
            const SizedBox(height: 14),
            _actionCard(
              icon: Icons.person,
              title: 'My Profile',
              subtitle: 'Language, area, contact & earnings',
              color: AppColors.primaryGreen,
              onTap: () => _openAndRefresh(const ProfileScreen()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeCard(String lang, String name) {
    final greeting = AppStrings.get(_greetingKey(), lang);
    final displayGreeting = name.isNotEmpty ? '$greeting, $name!' : greeting;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.lightGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.recycling, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayGreeting,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.get('subtitle', lang),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(String lang, int totalLots, double totalValue) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.inventory_2,
            label: AppStrings.get('totalLots', lang),
            value: '$totalLots',
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.currency_rupee,
            label: AppStrings.get('totalValue', lang),
            value: '₹${totalValue.toStringAsFixed(0)}',
            color: AppColors.primaryYellow,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
