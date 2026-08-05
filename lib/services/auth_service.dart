import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<T> _runWithRetry<T>(
    Future<T> Function() action, {
    int retries = 2,
  }) async {
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        return await action();
      } on FirebaseException catch (e) {
        final isTransient =
            e.code == 'unavailable' || e.code == 'deadline-exceeded';
        if (isTransient && attempt < retries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }

        if (e.code == 'unavailable') {
          throw 'The database service is temporarily unavailable. Please check your internet connection and try again.';
        }

        throw e.message ?? 'Firestore request failed.';
      } on SocketException {
        if (attempt < retries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        throw 'No internet connection. Please reconnect and try again.';
      }
    }

    throw 'Unable to complete the request right now.';
  }

  /// Assigns a role at registration.
  ///
  /// Admins pre-approve collector numbers in the `collectors` collection
  /// (whitelist). If the number is whitelisted the account becomes a
  /// 'collector', otherwise it is a regular 'client'.
  Future<String> determineRole(String phone) async {
    final normalizedPhone = phone.trim();

    if (normalizedPhone.isEmpty) {
      return 'client';
    }

    return _runWithRetry(() async {
      final doc = await _db.collection('collectors').doc(normalizedPhone).get();
      return doc.exists ? 'collector' : 'client';
    });
  }

  /// Returns true when an account already exists for this phone number.
  Future<bool> isPhoneRegistered(String phone) async {
    final normalizedPhone = phone.trim();

    if (normalizedPhone.isEmpty) {
      return false;
    }

    return _runWithRetry(() async {
      final doc = await _db.collection('users').doc(normalizedPhone).get();
      return doc.exists;
    });
  }

  Future<void> register(UserModel user) async {
    await _runWithRetry(() async {
      await _db.collection('users').doc(user.phoneNumber).set(user.toMap());
    });
  }

  Future<UserModel?> login(String phone, String password) async {
    return _runWithRetry<UserModel?>(() async {
      final doc = await _db.collection('users').doc(phone).get();

      if (doc.exists) {
        final user = UserModel.fromMap(doc.data()!);
        if (user.password == password) {
          return user;
        } else {
          throw "Incorrect Password";
        }
      } else {
        return null;
      }
    });
  }

  void signOut() {
    // In PIN mode, we just clear the local state via Provider later
  }
}
