// Smoke tests for Kabadiwala Connect's home screen.
//
// Uses hive_test to spin up a temporary, isolated Hive instance so tests
// don't touch a real device's storage and don't need platform plugins.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_test/hive_test.dart';

import 'package:kabadiwala_connect/main.dart';
import 'package:kabadiwala_connect/models/lot_store.dart';
import 'package:kabadiwala_connect/models/collector_store.dart';

void main() {
  setUp(() async {
    await setUpTestHive();
    await LotStore.init();
    await CollectorStore.init();
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  testWidgets('Home screen shows the three main action cards', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('Home screen shows zero lots and ₹0 on first launch',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
    expect(find.text('₹0'), findsOneWidget);
  });
}
