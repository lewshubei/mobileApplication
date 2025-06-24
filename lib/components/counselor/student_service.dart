import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getStudents() async {
    try {
      // Query users collection for students
      QuerySnapshot studentSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      // Get all user_assessments where shared_with_counselor is true
      QuerySnapshot assessmentSnapshot = await _firestore
          .collection('user_assessments')
          .where('shared_with_counselor', isEqualTo: true)
          .get();

      // Create a set of eligible user IDs from assessments
      Set<String> eligibleUserIds = {};
      for (var doc in assessmentSnapshot.docs) {
        Map<String, dynamic> assessmentData = doc.data() as Map<String, dynamic>;
        if (assessmentData.containsKey('userId')) {
          eligibleUserIds.add(assessmentData['userId']);
        }
      }

      // Process the results, filtering for students whose ID is in eligibleUserIds
      List<Map<String, dynamic>> students = [];
      for (var doc in studentSnapshot.docs) {
        Map<String, dynamic> studentData = doc.data() as Map<String, dynamic>;
        String userId = doc.id;
        
        // Only include students who have shared assessments
        if (eligibleUserIds.contains(userId)) {
          // Add document ID to the map
          studentData['id'] = userId;
          
          // Make sure we have a name for display
          studentData['name'] = studentData['name'] ?? 
                               studentData['displayName'] ?? 
                               'Unnamed Student';
          
          students.add(studentData);
        }
      }

      // Sort alphabetically by name
      students.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      
      return students;
    } catch (e) {
      print('Error fetching students: $e');
      throw e;
    }
  }

  // New method to get only students assigned to the current counselor
  Future<List<Map<String, dynamic>>> getAssignedStudents() async {
    try {
      // Get current user ID (counselor)
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }
      final String counselorId = currentUser.uid;

      // Get all counselor assignments for the current counselor
      QuerySnapshot assignmentsSnapshot = await _firestore
          .collection('counselor_assignments')
          .where('counselorId', isEqualTo: counselorId)
          .get();

      // Create a set of assigned student IDs
      Set<String> assignedStudentIds = {};
      for (var doc in assignmentsSnapshot.docs) {
        Map<String, dynamic> assignmentData = doc.data() as Map<String, dynamic>;
        if (assignmentData.containsKey('studentId')) {
          assignedStudentIds.add(assignmentData['studentId']);
        }
      }

      // If no assignments found, return empty list
      if (assignedStudentIds.isEmpty) {
        return [];
      }

      // Get all students with these IDs who have also shared assessments
      // First get students with shared assessments
      QuerySnapshot assessmentSnapshot = await _firestore
          .collection('user_assessments')
          .where('shared_with_counselor', isEqualTo: true)
          .get();

      // Filter to get eligible user IDs who have shared assessments
      Set<String> eligibleUserIds = {};
      for (var doc in assessmentSnapshot.docs) {
        Map<String, dynamic> assessmentData = doc.data() as Map<String, dynamic>;
        if (assessmentData.containsKey('userId') && 
            assignedStudentIds.contains(assessmentData['userId'])) {
          eligibleUserIds.add(assessmentData['userId']);
        }
      }

      // Get student details for eligible users
      List<Map<String, dynamic>> students = [];
      
      // Only proceed if there are eligible students
      if (eligibleUserIds.isNotEmpty) {
        // Firestore allows up to 10 items in an 'in' query, so we need to handle in batches if there are more
        List<List<String>> batches = [];
        List<String> currentBatch = [];
        int count = 0;
        
        for (String id in eligibleUserIds) {
          if (count == 10) {
            batches.add(currentBatch);
            currentBatch = [];
            count = 0;
          }
          currentBatch.add(id);
          count++;
        }
        
        if (currentBatch.isNotEmpty) {
          batches.add(currentBatch);
        }
        
        // Query each batch and collect results
        for (List<String> batch in batches) {
          QuerySnapshot batchSnapshot = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
              
          for (var doc in batchSnapshot.docs) {
            Map<String, dynamic> studentData = doc.data() as Map<String, dynamic>;
            String userId = doc.id;
            
            // Add document ID to the map
            studentData['id'] = userId;
            
            // Make sure we have a name for display
            studentData['name'] = studentData['name'] ?? 
                                studentData['displayName'] ?? 
                                'Unnamed Student';
            
            students.add(studentData);
          }
        }
      }

      // Sort alphabetically by name
      students.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      
      return students;
    } catch (e) {
      print('Error fetching assigned students: $e');
      throw e;
    }
  }
}
