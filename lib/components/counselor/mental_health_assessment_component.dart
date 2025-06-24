import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sentimo/screens/assessment_detail_screen.dart';

class MentalHealthAssessmentComponent extends StatelessWidget {
  final User? user;
  final Function(BuildContext) signOutCallback;

  const MentalHealthAssessmentComponent({
    super.key,
    required this.user,
    required this.signOutCallback,
  });

  @override
  Widget build(BuildContext context) {
    return _buildAssessmentsTab(context, user);
  }

  Widget _buildAssessmentsTab(BuildContext context, User? user) {
    if (user == null) {
      return const Center(
        child: Text('You need to be logged in to view assessments'),
      );
    }

    // Try to get user role first to avoid permission issues
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (userSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error accessing user data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(userSnapshot.error.toString()),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => signOutCallback(context),
                    child: const Text('Sign Out and Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final String userRole = userData?['role'] ?? 'unknown';

        if (userRole != 'counselor') {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Access Restricted',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account does not have counselor privileges required to view assessments.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // First, fetch the counselor's assigned students from the counselor_assignments collection
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('counselor_assignments')
              .where('counselorId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, assignmentsSnapshot) {
            if (assignmentsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (assignmentsSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Permission Error',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        assignmentsSnapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final assignments = assignmentsSnapshot.data?.docs ?? [];
            
            // Extract the studentIds from assignments
            final List<String> assignedStudentIds = assignments
                .map((doc) => (doc.data() as Map<String, dynamic>)['studentId'] as String)
                .toList();
            
            if (assignedStudentIds.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Assigned Students',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You don\'t have any students assigned to you yet.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // Now fetch assessments where shared_with_counselor is true AND the userId is in the assignedStudentIds list
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_assessments')
                  .where('shared_with_counselor', isEqualTo: true)
                  .where('userId', whereIn: assignedStudentIds)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Error Loading Assessments',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final assessments = snapshot.data?.docs ?? [];

                if (assessments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.assessment,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Assessments Available',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'None of your assigned students have shared their assessments with counselors yet.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
                  itemCount: assessments.length,
                  itemBuilder: (context, index) {
                    try {
                      final assessmentDoc = assessments[index];
                      final assessment =
                          assessmentDoc.data() as Map<String, dynamic>;
                      final DateTime timestamp =
                          (assessment['timestamp'] as Timestamp).toDate();
                      final String userId = assessment['userId'] as String;

                      // Format timestamp to a readable string
                      final String formattedDate = DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(timestamp);

                      return _buildAssessmentListItem(
                        context,
                        userId: userId,
                        formattedDate: formattedDate,
                        assessmentDoc: assessmentDoc,
                      );
                    } catch (e) {
                      return ListTile(
                        title: Text('Error loading assessment'),
                        subtitle: Text(e.toString()),
                        tileColor: Colors.red.shade50,
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAssessmentListItem(
    BuildContext context, {
    required String userId,
    required String formattedDate,
    required DocumentSnapshot assessmentDoc,
  }) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        // Default student name placeholder
        String studentName = 'Loading...';
        String initial = 'S';

        if (userSnapshot.connectionState == ConnectionState.waiting) {
          // Show loading placeholder while waiting for data
          studentName = 'Loading...';
        } else if (userSnapshot.hasError) {
          // Show error placeholder if there's an error
          studentName = 'Unknown Student';
        } else if (userSnapshot.hasData && userSnapshot.data != null) {
          // Extract student name from user data
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

          // Try multiple possible name fields, prioritizing 'name'
          studentName =
              userData?['name'] ??
              userData?['displayName'] ??
              userData?['fullName'] ??
              (userData?['firstName'] != null
                  ? '${userData?['firstName']} ${userData?['lastName'] ?? ''}'
                  : 'Student ${userId.substring(0, 4)}');

          // Get the initial for the avatar
          if (studentName.trim().isNotEmpty) {
            initial = studentName.trim()[0].toUpperCase();
          }
        }

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                ),
              ),
            ),
            title: Text(
              studentName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text('Submitted on $formattedDate'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => AssessmentDetailScreen(
                        assessmentId: assessmentDoc.id,
                        studentId: userId,
                      ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
