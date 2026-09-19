import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Implements the Form-6 manifest's "chainHash" concept from the data
/// dictionary: each of the three checkpoints (dispatch, transit,
/// delivery) folds the previous stage's hash into its own, so the final
/// hash breaks if any earlier checkpoint is altered after the fact.
///
/// This is what "encrypted 3 times, like the offline process" becomes in
/// digital form here: three chained SHA-256 hashes, one per physical
/// hand-off, rather than a literal triple-encryption of the document.
/// Be upfront with anyone reviewing this that it's tamper-evidence
/// (detects changes), not encryption (which would hide content) — say so
/// if asked, rather than overclaiming what it does.
class CryptoService {
  static String hash(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  /// Folds one checkpoint's signature into the running chain.
  static String chainHash({
    required String previousHash,
    required String stageSignatureHash,
    required DateTime timestamp,
    double? latitude,
    double? longitude,
  }) {
    final payload =
        '$previousHash|$stageSignatureHash|${timestamp.toIso8601String()}|$latitude|$longitude';
    return hash(payload);
  }
}
