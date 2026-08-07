import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

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
    final phone = prefs.getString('saved_phone');
    if (phone == null) return;
    await refreshUser(phone);
  }

  // 3. Fetch/Refresh user data from Firestore
  Future<void> refreshUser(String phone) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Essaie la clé telle que sauvegardée, puis sa forme canonique
      // (+237...) : un doc créé à la main dans la console peut avoir une
      // clé différente du champ phoneNumber (ex. clé '677123456', champ
      // '+237677123456').
      _user = null;
      for (final key in AuthService.canonicalKeys(phone)) {
        if (key.isEmpty) continue;
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(key)
            .get();
        if (doc.exists) {
          _user = UserModel.fromMap(doc.data()!);
          break;
        }
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
