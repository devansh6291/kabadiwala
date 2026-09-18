import 'package:hive_flutter/hive_flutter.dart';
import 'lot.dart';
import 'lot_hive_adapter.dart';

/// Offline-first storage for [Lot] records.
///
/// Backed by Hive so a collector's lots survive app restarts and are
/// available with zero connectivity. This store only ever touches the
/// on-device copy; the actual sync to the backend (flipping `syncStatus`
/// from "pending" to "synced"/"failed") is a separate concern for the
/// sync layer to implement.
class LotStore {
  static const String boxName = 'lots';
  static Box<Lot>? _box;

  /// Call once, before runApp(), after Hive.initFlutter().
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
        'LotStore.init() must be called and awaited before use (see main.dart).',
      );
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

  /// Newest lots first.
  static List<Lot> getAllLots() {
    final lots = _requireBox.values.toList();
    lots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return lots;
  }

  /// Notifies listeners (e.g. the history screen) whenever a lot is
  /// added, updated, or removed — including once the sync layer flips
  /// a lot's syncStatus in the background.
  static Stream<BoxEvent> watch() => _requireBox.watch();
}