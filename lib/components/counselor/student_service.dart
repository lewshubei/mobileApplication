import 'package:cloud_firestore/cloud_firestore.dart';

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
}
