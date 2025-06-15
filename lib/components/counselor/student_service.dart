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

      // Process the results
      List<Map<String, dynamic>> students = [];
      for (var doc in studentSnapshot.docs) {
        Map<String, dynamic> studentData = doc.data() as Map<String, dynamic>;
        
        // Add document ID to the map
        studentData['id'] = doc.id;
        
        // Make sure we have a name for display
        studentData['name'] = studentData['name'] ?? 
                             studentData['displayName'] ?? 
                             'Unnamed Student';
        
        students.add(studentData);
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
