import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Manages Firebase Authentication (Phone OTP) and Cloud Storage uploads.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  FirebaseService._internal();

  /// Initialize Firebase before running the app.
  static Future<void> init() async {
    await Firebase.initializeApp();
  }

  /// Current logged-in user.
  User? get currentUser => _auth.currentUser;

  /// Retrieves the current user's Firebase ID Token (JWT)
  /// to authenticate outgoing Dio requests.
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('[FIREBASE AUTH ERROR] Failed to fetch ID token: $e');
      return null;
    }
  }

  /// Sends a Phone OTP verification code.
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException error) onVerificationFailed,
    required Function(PhoneAuthCredential credential) onAutoVerified,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onAutoVerified,
      verificationFailed: onVerificationFailed,
      codeSent: (String verificationId, int? token) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Verifies the SMS OTP and completes login.
  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  /// Uploads a local image file to Firebase Cloud Storage and returns its public URL.
  Future<String> uploadLotPhoto({
    required String lotId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('File does not exist at path: $localPath');
    }

    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${localPath.split('/').last}';
    final ref = _storage.ref().child('lots').child(lotId).child(filename);

    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Logs out the collector.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
