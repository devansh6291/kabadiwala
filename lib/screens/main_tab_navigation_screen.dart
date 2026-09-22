import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'recycler_data_screen.dart';
import 'nearby_kabadiwalas_screen.dart';
import 'price_discovery_screen.dart';
import 'market_news_screen.dart';

/// Bottom-tab shell wrapping the home dashboard plus four info tabs.
class MainTabNavigationScreen extends StatefulWidget {
  final String currentLanguage;
  final ValueChanged<String?> onLanguageChanged;

  const MainTabNavigationScreen({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  State<MainTabNavigationScreen> createState() =>
      _MainTabNavigationScreenState();
}

class _MainTabNavigationScreenState extends State<MainTabNavigationScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(
        currentLanguage: widget.currentLanguage,
        onLanguageChanged: widget.onLanguageChanged,
      ),
      const RecyclerDataScreen(),
      const NearbyKabadiwalasScreen(),
      const PriceDiscoveryScreen(),
      const MarketNewsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.factory_outlined),
              selectedIcon: Icon(Icons.factory),
              label: 'Recyclers'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Nearby'),
          NavigationDestination(
              icon: Icon(Icons.currency_rupee),
              selectedIcon: Icon(Icons.currency_rupee),
              label: 'Prices'),
          NavigationDestination(
              icon: Icon(Icons.newspaper_outlined),
              selectedIcon: Icon(Icons.newspaper),
              label: 'News'),
        ],
      ),
    );
  }
}
