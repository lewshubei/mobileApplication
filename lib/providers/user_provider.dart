import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  User? _user;
  String? _avatarUrl;
  String? _phoneNumber;

  User? get user => _user;
  String? get avatarUrl => _avatarUrl;
  String? get phoneNumber => _phoneNumber;

  void setUser(User? user) {
    _user = user;
    notifyListeners();
  }

  void updateUser(User? user) {
    _user = user;
    _avatarUrl = user?.photoURL;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      await _loadUserData();
    }
    notifyListeners();
  }

  Future<void> _loadUserData() async {
    _avatarUrl = user?.photoURL;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();

    if (doc.exists) {
      _avatarUrl = doc.data()?['_avatarUrl'] ?? user?.photoURL;
      _phoneNumber = doc.data()?['phoneNumber'];
    }
  }

  Future<void> updateAvatar(String imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.updatePhotoURL(imageUrl);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'avatarUrl': imageUrl,
      }, SetOptions(merge: true));

      // Update local user data
      _user = FirebaseAuth.instance.currentUser;
      notifyListeners();
    } catch (e) {
      print('Error updating avatar: $e');
      throw e;
    }
  }

  Future<void> updatePhoneNumber(String number) async {
    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
      'phoneNumber': number,
    }, SetOptions(merge: true));

    _phoneNumber = number;
    notifyListeners();
  }
}
