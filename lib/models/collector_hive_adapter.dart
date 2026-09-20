import 'package:hive/hive.dart';
import 'collector.dart';

/// Hand-written Hive adapter, same pattern as LotAdapter — no
/// build_runner needed. Uses typeId 1 (LotAdapter already uses 0).
class CollectorProfileAdapter extends TypeAdapter<CollectorProfile> {
  @override
  final int typeId = 1;

  @override
  CollectorProfile read(BinaryReader reader) {
    final raw = reader.readMap();
    final json = raw.map((key, value) => MapEntry(key.toString(), value));
    return CollectorProfile.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, CollectorProfile obj) {
    writer.writeMap(obj.toJson());
  }
}
