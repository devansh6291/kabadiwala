import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_colors.dart';
import 'app_strings.dart';
import 'models/lot_store.dart';
import 'screens/create_lot_screen.dart';
import 'screens/lot_history_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LotStore.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String currentLanguage = 'en';

  void changeLanguage(String? newLanguage) {
    if (newLanguage == null) return;
    setState(() {
      currentLanguage = newLanguage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kabadiwala Connect',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          secondary: AppColors.primaryYellow,
        ),
      ),
      home: HomeScreen(
        currentLanguage: currentLanguage,
        onLanguageChanged: changeLanguage,
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final String currentLanguage;
  final ValueChanged<String?> onLanguageChanged;

  const HomeScreen({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('appTitle', currentLanguage)),
        actions: [
          DropdownButton<String>(
            value: currentLanguage,
            dropdownColor: AppColors.primaryGreen,
            underline: const SizedBox(),
            icon: const Icon(Icons.language, color: Colors.white),
            onChanged: onLanguageChanged,
            items: AppStrings.languageNames.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(
                  entry.value,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateLotScreen()),
                  );
                },
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Create Lot'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              height: 56,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LotHistoryScreen()),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('My Lots'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}