import 'package:hive/hive.dart';
import 'lot.dart';

/// Hand-written Hive adapter for [Lot].
///
/// This is written by hand instead of via `build_runner`/`hive_generator`
/// so the model works without running Flutter's code-generation step.
class LotAdapter extends TypeAdapter<Lot> {
  @override
  final int typeId = 0;

  @override
  Lot read(BinaryReader reader) {
    final raw = reader.readMap();
    final json = raw.map((key, value) => MapEntry(key.toString(), value));
    return Lot.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, Lot obj) {
    writer.writeMap(obj.toJson());
  }
}