import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sentimo/models/user_role.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the current user's role
  Future<UserRole> getCurrentUserRole() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists && doc.data()!.containsKey('role')) {
        return UserRoleExtension.fromString(doc.data()!['role']);
      } else {
        // Default role if not set
        return UserRole.student;
      }
    } catch (e) {
      print('Error getting user role: $e');
      // Default to student if there's an error
      return UserRole.student;
    }
  }

  // Save user role to Firestore
  Future<void> saveUserRole(String userId, UserRole role) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'role': role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving user role: $e');
      throw Exception('Failed to save user role');
    }
  }
}
