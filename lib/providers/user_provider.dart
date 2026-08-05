import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  // 1. Set User and Persist Session
  Future<void> setUser(UserModel user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'saved_phone',
      user.phoneNumber,
    ); // Save phone locally
    notifyListeners();
  }

  // 2. Try Auto-Login on Startup
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('saved_phone')) return;

    String? phone = prefs.getString('saved_phone');
    if (phone != null) {
      await refreshUser(phone);
    }
  }

  // 3. Fetch/Refresh user data from Firestore
  Future<void> refreshUser(String phone) async {
    _isLoading = true;
    notifyListeners();
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(phone)
          .get();
      if (doc.exists) {
        _user = UserModel.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  // 4. Logout and Clear Session
  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_phone'); // Delete saved session
    notifyListeners();
  }
}
