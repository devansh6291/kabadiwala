import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_colors.dart';
import 'models/lot_store.dart';
import 'models/collector_store.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/firebase_service.dart';
import 'services/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await FirebaseService.init();

  // 2. Initialize Hive local databases
  await Hive.initFlutter();
  await LotStore.init();
  await CollectorStore.init();

  // TEMPORARY: override for physical-device USB testing via `adb reverse`.
  // Remove or make this conditional once testing on an emulator or over
  // real WiFi with a LAN IP instead.
  ApiClient().updateBaseUrl('http://10.77.222.41:8000');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String currentLanguage = 'en';
  late bool _onboarded = CollectorStore.isOnboarded();

  void changeLanguage(String? newLanguage) {
    if (newLanguage == null) return;
    setState(() => currentLanguage = newLanguage);
  }

  void _onLoginComplete(String chosenLanguage) {
    setState(() {
      currentLanguage = chosenLanguage;
      _onboarded = true;
    });
  }

  @override
  void initState() {
    super.initState();
    if (_onboarded) {
      currentLanguage = CollectorStore.getOrCreate().preferredLanguage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kabadiwala Connect',
      debugShowCheckedModeBanner: false,
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
      home: _onboarded
          ? HomeScreen(
              currentLanguage: currentLanguage,
              onLanguageChanged: changeLanguage,
            )
          : LoginScreen(onComplete: _onLoginComplete),
    );
  }
}
