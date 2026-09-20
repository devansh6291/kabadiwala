import 'package:hive_flutter/hive_flutter.dart';
import 'lot.dart';
import 'lot_hive_adapter.dart';

/// Offline-first storage for Lot records.
class LotStore {
  static const String boxName = 'lots';
  static Box<Lot>? _box;

  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LotAdapter());
    }
    _box = await Hive.openBox<Lot>(boxName);
  }

  static Box<Lot> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError(
          'LotStore.init() must be called and awaited before use.');
    }
    return box;
  }

  static Future<void> addLot(Lot lot) async {
    await _requireBox.put(lot.id, lot);
  }

  static Future<void> updateLot(Lot lot) async {
    await _requireBox.put(lot.id, lot);
  }

  static Future<void> deleteLot(String id) async {
    await _requireBox.delete(id);
  }

  /// Returns all lots ordered newest first.
  static List<Lot> getAllLots() {
    final lots = _requireBox.values.toList();
    lots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return lots;
  }

  /// Real-time stream alerting screens when sync updates occur.
  static Stream<BoxEvent> watch() => _requireBox.watch();
}
