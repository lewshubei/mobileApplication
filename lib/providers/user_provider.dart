import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  User? _user;
  String? _avatarBase64;
  String? _phoneNumber;

  User? get user => _user;
  String? get avatarBase64 => _avatarBase64;
  String? get phoneNumber => _phoneNumber;

  void updateUser(User? user) {
    _user = user;
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
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();

    if (doc.exists) {
      _avatarBase64 = doc.data()?['avatar'];
      _phoneNumber = doc.data()?['phoneNumber'];
    }
  }

  Future<void> updateAvatar(String base64Image) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .set({'avatar': base64Image}, SetOptions(merge: true));
      
      _avatarBase64 = base64Image;
      notifyListeners();
    } catch (e) {
      print('Error updating avatar: $e');
      rethrow;
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
