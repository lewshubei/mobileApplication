import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch appointments for a specific counselor
  Future<List<Map<String, dynamic>>> getAppointmentsForCounselor(
    String counselorId,
    String statusFilter,
  ) async {
    try {
      // Convert status filter to match Firestore field values
      String status;
      switch (statusFilter) {
        case 'Upcoming':
          status = 'upcoming';
          break;
        case 'Past':
          status = 'completed';
          break;
        case 'Cancelled':
          status = 'cancelled';
          break;
        default:
          status = 'upcoming';
      }

      // Query appointments collection with filters
      QuerySnapshot appointmentSnapshot =
          await _firestore
              .collection('appointments')
              .where('counselorId', isEqualTo: counselorId)
              .where('status', isEqualTo: status)
              .get();

      // Process the results
      List<Map<String, dynamic>> appointments = [];
      for (var doc in appointmentSnapshot.docs) {
        Map<String, dynamic> appointmentData =
            doc.data() as Map<String, dynamic>;

        // Add document ID to the map
        appointmentData['id'] = doc.id;

        // Get client information
        String clientId = appointmentData['clientId'];
        DocumentSnapshot clientDoc =
            await _firestore.collection('users').doc(clientId).get();

        if (clientDoc.exists) {
          Map<String, dynamic>? clientData =
              clientDoc.data() as Map<String, dynamic>?;
          if (clientData != null && clientData['role'] == 'student') {
            // Add client name to appointment data
            appointmentData['clientName'] = clientData['name'];

            // Convert Firestore Timestamp to DateTime
            appointmentData['dateTime'] =
                (appointmentData['datetime'] as Timestamp).toDate();

            // Match status format with UI expectations
            appointmentData['status'] = statusFilter;

            appointments.add(appointmentData);
          }
        }
      }

      return appointments;
    } catch (e) {
      print('Error fetching appointments: $e');
      rethrow;
    }
  }

  // Search appointments by client name
  Future<List<Map<String, dynamic>>> searchAppointmentsByClientName(
    String counselorId,
    String statusFilter,
    String searchQuery,
  ) async {
    try {
      // First, get all appointments for this counselor with the given status
      List<Map<String, dynamic>> allAppointments =
          await getAppointmentsForCounselor(counselorId, statusFilter);

      // Then filter by client name
      return allAppointments
          .where(
            (appointment) => appointment['clientName']
                .toString()
                .toLowerCase()
                .contains(searchQuery.toLowerCase()),
          )
          .toList();
    } catch (e) {
      print('Error searching appointments: $e');
      rethrow;
    }
  }

  // Delete an appointment by ID
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).delete();
    } catch (e) {
      print('Error deleting appointment: $e');
      rethrow;
    }
  }
}
