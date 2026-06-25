import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Send SMS Code
  Future<void> verifyPhoneNumber(
    String phone, {
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Automatic handling on some Android phones
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? "Verification Failed");
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // 2. Verify OTP and Sign In
  Future<UserCredential?> signInWithOTP(
    String verificationId,
    String smsCode,
  ) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Error signing in: $e");
      return null;
    }
  }

  // 3. Check if user exists in our Firestore database
  Future<bool> checkIfUserExists(String uid) async {
    DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }
  // Add this inside the AuthService class

  // 4. Create User Profile in Firestore
  Future<void> createUserProfile(UserModel user) async {
    try {
      await _db.collection('users').doc(user.uid).set(user.toMap());
    } catch (e) {
      print("Error creating user profile: $e");
      rethrow; // Pass the error to the UI to show a snackbar
    }
  }

  // 6. Sign out helper
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 5. Get current Firebase User
  User? get currentUser => _auth.currentUser;
}
