import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'dart:math' as Math;
import 'package:sentimo/components/counselor/create_appointment_component.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssessmentDetailScreen extends StatefulWidget {
  final String assessmentId;
  final String studentId;

  const AssessmentDetailScreen({
    super.key,
    required this.assessmentId,
    required this.studentId,
  });

  @override
  State<AssessmentDetailScreen> createState() => _AssessmentDetailScreenState();
}

class _AssessmentDetailScreenState extends State<AssessmentDetailScreen> {
  String? selectedCounselorId;
  bool isAssigning = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentAssignment();
  }

  Future<void> _loadCurrentAssignment() async {
    try {
      // Get current assignment from user_assignments collection or the user document itself
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.studentId)
              .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData.containsKey('assignedCounselorId')) {
          setState(() {
            selectedCounselorId = userData['assignedCounselorId'];
          });
        }
      }
    } catch (e) {
      print('Error loading counselor assignment: $e');
    }
  }

  Future<void> _assignCounselor(
    String counselorId,
    String counselorName,
  ) async {
    setState(() {
      isAssigning = true;
    });

    try {
      // Update the user document with the assigned counselor
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .update({
            'assignedCounselorId': counselorId,
            'assignedCounselorName': counselorName,
            'assignmentDate': FieldValue.serverTimestamp(),
          });

      // Optionally, create an assignment record in a separate collection
      await FirebaseFirestore.instance.collection('counselor_assignments').add({
        'studentId': widget.studentId,
        'counselorId': counselorId,
        'counselorName': counselorName,
        'assessmentId': widget.assessmentId,
        'assignmentDate': FieldValue.serverTimestamp(),
      });

      setState(() {
        selectedCounselorId = counselorId;
        isAssigning = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Student assigned to $counselorName')),
      );
    } catch (e) {
      setState(() {
        isAssigning = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error assigning counselor: $e')));
    }
  }
  
  void _makeAppointment(BuildContext context) async {
    try {
      // Get student information
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .get();
          
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student information not found')),
        );
        return;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final String studentName = userData['name'] ?? 
                                userData['displayName'] ?? 
                                'Student ${widget.studentId.substring(0, 4)}';
      
      // Get the current user (counselor)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to create appointments')),
        );
        return;
      }
      
      // Navigate to the Create Appointment screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CreateAppointmentComponent(
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: (appointmentData) => _createAppointment(appointmentData, user.uid),
            preSelectedStudentId: widget.studentId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating appointment: $e')),
      );
    }
  }

  void _rescheduleAppointment(BuildContext context, String appointmentId) async {
    try {
      // Get the current appointment data
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
          
      if (!appointmentDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment not found')),
        );
        return;
      }
      
      // Get the current user (counselor)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to reschedule appointments')),
        );
        return;
      }
      
      // Navigate to the Create Appointment screen with pre-filled data
      final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CreateAppointmentComponent(
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: (updatedData) => _updateAppointment(appointmentId, updatedData),
            preSelectedStudentId: widget.studentId,
            // Could pass other pre-filled appointment data here if CreateAppointmentComponent supports it
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rescheduling appointment: $e')),
      );
    }
  }

  void _cancelAppointment(BuildContext context, String appointmentId) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Appointment'),
          content: const Text('Are you sure you want to cancel this appointment?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('NO'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('YES'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
      
      // Update appointment status to cancelled
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });
          
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling appointment: $e')),
      );
    }
  }
  
  Future<void> _createAppointment(Map<String, dynamic> appointmentData, String counselorId) async {
    try {
      // Add counselor ID and assignment info to the appointment data
      appointmentData['counselorId'] = counselorId;
      appointmentData['assignedBy'] = counselorId;
      appointmentData['assignmentDate'] = FieldValue.serverTimestamp();
      appointmentData['studentId'] = widget.studentId;
      
      // Save to Firestore
      await FirebaseFirestore.instance.collection('appointments').add(appointmentData);
      
      // Return to previous screen
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment created successfully')),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create appointment: ${e.toString()}')),
        );
      }
    }
  }
  
  Future<void> _updateAppointment(String appointmentId, Map<String, dynamic> appointmentData) async {
    try {
      // Update the existing appointment
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update(appointmentData);
      
      // Return to previous screen
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment rescheduled successfully')),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reschedule appointment: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment Details')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStudentSection(context),
          const SizedBox(height: 24),
          _buildAssessmentSection(context),
        ],
      ),
    );
  }

  Widget _buildStudentSection(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.studentId)
              .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('Error loading student data: ${snapshot.error}'),
                  ],
                ),
              ),
            ),
          );
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>?;

        // Based on the provided user data structure, using 'name' field first
        final String studentName =
            userData?['name'] ??
            userData?['displayName'] ??
            'Student ${widget.studentId.substring(0, 4)}';

        final String email = userData?['email'] ?? '';

        // Extract first initial for avatar
        String initial = 'S';
        if (studentName.trim().isNotEmpty) {
          initial = studentName.trim()[0].toUpperCase();
        }

        return SizedBox(
          width: double.infinity,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.teal.shade100,
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildCounselorAssignment(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCounselorAssignment(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('studentId', isEqualTo: widget.studentId)
          .orderBy('datetime', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Error loading appointment information: ${snapshot.error}',
            style: TextStyle(color: Colors.red.shade400),
          );
        }

        final appointments = snapshot.data?.docs ?? [];
        
        // Check if there's an appointment for this student
        if (appointments.isNotEmpty) {
          final appointmentDoc = appointments.first;
          final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
          final appointmentId = appointmentDoc.id;
          final counselorId = appointmentData['counselorId'];
          final appointmentTimestamp = appointmentData['datetime'] as Timestamp?;
          final appointmentDateTime = appointmentTimestamp?.toDate();
          final formattedDate = appointmentDateTime != null 
              ? DateFormat('MMMM dd, yyyy - HH:mm').format(appointmentDateTime) 
              : 'Date not specified';
          final sessionType = appointmentData['sessionType'] ?? 'Not specified';
          final status = appointmentData['status'] ?? 'upcoming';
          final bool canReschedule = status.toLowerCase() == 'upcoming';

          // Use FutureBuilder to fetch counselor name from users collection
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(counselorId).get(),
            builder: (context, counselorSnapshot) {
              // Default counselor name (while loading or if error occurs)
              String counselorName = appointmentData['counselorName'] ?? 'Unknown Counselor';
              
              // If we successfully retrieved the counselor document, get the name
              if (counselorSnapshot.connectionState == ConnectionState.done && 
                  counselorSnapshot.hasData && 
                  counselorSnapshot.data!.exists) {
                final counselorData = counselorSnapshot.data!.data() as Map<String, dynamic>?;
                if (counselorData != null) {
                  counselorName = counselorData['name'] ?? 
                                 counselorData['displayName'] ?? 
                                 counselorName;
                }
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.event, size: 20, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Appointment Information',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      // Replace kebab menu with New Appointment button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("New Appointment"),
                        onPressed: () => _makeAppointment(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'With: $counselorName',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: $formattedDate',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type: $sessionType',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${status.substring(0, 1).toUpperCase()}${status.substring(1)}',
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
          );
        } else {
          // If no appointment exists, show fallback message with assigned counselor info if available
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'counselor')
                .snapshots(),
            builder: (context, counselorSnapshot) {
              String currentAssignmentText = 'No appointment assigned yet';

              // Check if student has assigned counselor
              if (selectedCounselorId != null && counselorSnapshot.hasData) {
                final counselors = counselorSnapshot.data?.docs ?? [];
                final assignedCounselorDoc = counselors.firstWhereOrNull(
                  (doc) => doc.id == selectedCounselorId,
                );

                if (assignedCounselorDoc != null) {
                  final counselorData = assignedCounselorDoc.data() as Map<String, dynamic>?;
                  if (counselorData != null) {
                    currentAssignmentText =
                        'Assigned counselor: ${counselorData['name'] ?? counselorData['displayName'] ?? 'Unknown Counselor'}';
                  }
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.event, size: 20, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Appointment Information',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      // Replace kebab menu with New Appointment button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("New Appointment"),
                        onPressed: () => _makeAppointment(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentAssignmentText,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              );
            },
          );
        }
      },
    );
  }

  // Add this helper method to the _AssessmentDetailScreenState class
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
        return Colors.blue.shade700;
      case 'completed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 70) {
      return Colors.green.shade700;
    } else if (score >= 40) {
      return Colors.amber.shade700;
    } else {
      return Colors.red.shade700;
    }
  }

  String _getScoreDescription(double score) {
    if (score >= 70) {
      return "Good mental health state";
    } else if (score >= 40) {
      return "Moderate mental health concerns";
    } else {
      return "Significant mental health concerns";
    }
  }

  void _showCounselorSelectionDialog(
    BuildContext context,
    List<QueryDocumentSnapshot> counselors,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Assign Counselor'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: counselors.length,
              itemBuilder: (context, index) {
                final counselor = counselors[index];
                final counselorData = counselor.data() as Map<String, dynamic>;
                final counselorName =
                    counselorData['name'] ??
                    counselorData['displayName'] ??
                    'Counselor ${counselor.id.substring(0, 4)}';
                final isCurrentlySelected = counselor.id == selectedCounselorId;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isCurrentlySelected
                            ? Colors.teal.shade100
                            : Colors.grey.shade100,
                    child: Text(
                      counselorName.isNotEmpty
                          ? counselorName[0].toUpperCase()
                          : 'C',
                      style: TextStyle(
                        color:
                            isCurrentlySelected
                                ? Colors.teal.shade700
                                : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(counselorName),
                  subtitle: Text(counselorData['email'] ?? ''),
                  selected: isCurrentlySelected,
                  onTap: () {
                    Navigator.of(context).pop();
                    _assignCounselor(counselor.id, counselorName);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAssessmentSection(BuildContext context) {
    // Get current logged-in counselor ID
    final currentCounselorId = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentCounselorId == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Please log in to view assessments'),
        ),
      );
    }

    // First check if the counselor is assigned to this student
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
        .collection('users')
        .doc(widget.studentId)
        .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (userSnapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Error loading user data: ${userSnapshot.error}'),
                ],
              ),
            ),
          );
        }
        
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.person_off, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('Student record not found'),
                ],
              ),
            ),
          );
        }
        
        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final String? assignedCounselorId = userData?['assignedCounselorId'];
        
        // Check if the current counselor is assigned to this student
        if (assignedCounselorId != currentCounselorId) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.security, color: Colors.orange),
                  const SizedBox(height: 8),
                  const Text('You are not assigned to this student.'),
                  const Text('Only the assigned counselor can view their assessments.'),
                ],
              ),
            ),
          );
        }
        
        // If the counselor is assigned to this student, now check the assessment
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('user_assessments')
              .doc(widget.assessmentId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('Error loading assessment data: ${snapshot.error}'),
                    ],
                  ),
                ),
              );
            }

            final assessmentData = snapshot.data?.data() as Map<String, dynamic>?;

            if (assessmentData == null) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Assessment data not found'),
                ),
              );
            }
            
            // Check if assessment is shared with counselor
            final bool sharedWithCounselor = assessmentData['shared_with_counselor'] ?? false;
            
            if (!sharedWithCounselor) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.lock, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('This assessment is not shared with counselors'),
                    ],
                  ),
                ),
              );
            }

            final List<dynamic> answers = assessmentData['answers'] ?? [];
            final DateTime timestamp =
                (assessmentData['timestamp'] as Timestamp).toDate();
            final String formattedDate = DateFormat(
              'MMMM dd, yyyy - HH:mm',
            ).format(timestamp);
            final int totalQuestions = answers.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assessment info header - Full width
                SizedBox(
                  width: double.infinity,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assessment Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Submitted on $formattedDate'),
                          const SizedBox(height: 4),
                          Text('Total Questions: $totalQuestions'),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Assessment results header
                const Text(
                  'Assessment Results',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                // Score display card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overall Score',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: (assessmentData['score'] ?? 0) / 100,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getScoreColor(assessmentData['score'] ?? 0),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '${(assessmentData['score'] ?? 0).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _getScoreColor(assessmentData['score'] ?? 0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getScoreDescription(assessmentData['score'] ?? 0),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Questions and answers - Full width
                ...List.generate(answers.length, (index) {
                  final answer = answers[index];
                  final String question =
                      answer['question'] ?? 'Question not available';
                  final String answerText = answer['answer'] ?? 'No answer';
                  final int questionNumber = index + 1;

                  return SizedBox(
                    width: double.infinity,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Question number
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.only(right: 10, top: 0),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$questionNumber',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                // Question text
                                Expanded(
                                  child: Text(
                                    question,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 38,
                                ), // Align with question text
                                const Text(
                                  'Answer: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    answerText,
                                    style: TextStyle(
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}
