import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  // 1. Fetch user data from Firestore
  Future<void> refreshUser(String uid) async {
    _isLoading = true;
    notifyListeners(); // Tell the UI we are loading

    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        _user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print("Error fetching user: $e");
    }

    _isLoading = false;
    notifyListeners(); // Tell the UI loading is finished
  }

  // 2. Clear user (for Logout)
  void clearUser() {
    _user = null;
    notifyListeners();
  }
}
