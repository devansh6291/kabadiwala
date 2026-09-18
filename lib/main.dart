import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_strings.dart';
import 'screens/create_lot_screen.dart';

void main() {
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
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateLotScreen()),
            );
          },
          child: const Text('Create Lot'),
        ),
      ),
    );
  }
}