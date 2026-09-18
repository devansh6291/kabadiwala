class AppStrings {
  static const Map<String, Map<String, String>> translations = {
    'en': {
      'appTitle': 'Kabadiwala Connect',
      'greeting': 'Hello, Kabadiwala Connect!',
    },
    'hi': {
      'appTitle': 'कबाड़ीवाला कनेक्ट',
      'greeting': 'नमस्ते, कबाड़ीवाला कनेक्ट!',
    },
    'mr': {
      'appTitle': 'कबाडीवाला कनेक्ट',
      'greeting': 'नमस्कार, कबाडीवाला कनेक्ट!',
    },
    'te': {
      'appTitle': 'కబాడీవాలా కనెక్ట్',
      'greeting': 'నమస్కారం, కబాడీవాలా కనెక్ట్!',
    },
    'ml': {
      'appTitle': 'കബാഡിവാല കണക്ട്',
      'greeting': 'നമസ്കാരം, കബാഡിവാല കണക്ട്!',
    },
    'ta': {
      'appTitle': 'கபாடிவாலா கனெக்ட்',
      'greeting': 'வணக்கம், கபாடிவாலா கனெக்ட்!',
    },
    'bho': {
      'appTitle': 'कबाड़ीवाला कनेक्ट',
      'greeting': 'प्रणाम, कबाड़ीवाला कनेक्ट!',
    },
    'gu': {
      'appTitle': 'કબાડીવાલા કનેક્ટ',
      'greeting': 'નમસ્તે, કબાડીવાલા કનેક્ટ!',
    },
  };

  static const Map<String, String> languageNames = {
    'en': 'English',
    'hi': 'हिंदी',
    'mr': 'मराठी',
    'te': 'తెలుగు',
    'ml': 'മലയാളം',
    'ta': 'தமிழ்',
    'bho': 'भोजपुरी',
    'gu': 'ગુજરાતી',
  };

  static String get(String key, String languageCode) {
    return translations[languageCode]?[key] ?? key;
  }
}