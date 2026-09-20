import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'collector.dart';
import 'collector_hive_adapter.dart';

/// Offline-first storage for this device's single collector profile.
class CollectorStore {
  static const String boxName = 'collector_profile';
  static const String _key = 'me';
  static Box<CollectorProfile>? _box;

  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CollectorProfileAdapter());
    }
    _box = await Hive.openBox<CollectorProfile>(boxName);
  }

  static Box<CollectorProfile> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('CollectorStore.init() must be called before use.');
    }
    return box;
  }

  static CollectorProfile getOrCreate({String? phoneNumber}) {
    final existing = _requireBox.get(_key);
    if (existing != null) return existing;

    final fresh = CollectorProfile(
      collectorId: const Uuid().v4(),
      phoneNumber: phoneNumber ?? '',
    );
    _requireBox.put(_key, fresh);
    return fresh;
  }

  static bool isOnboarded() => _requireBox.get(_key)?.isOnboarded ?? false;

  static Future<void> save(CollectorProfile profile) async {
    await _requireBox.put(_key, profile);
  }
}
