import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MentalHealthAssessmentComponent extends StatelessWidget {
  final User? user;
  final Function(BuildContext) signOutCallback;

  const MentalHealthAssessmentComponent({
    Key? key,
    required this.user,
    required this.signOutCallback,
  }) : super(key: key);

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
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
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
        
        // Now that we've verified the user is a counselor, fetch the assessments
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('user_assessments')
              .where('shared_with_counselor', isEqualTo: true)
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
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Permission Error',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Please ensure your Firestore security rules allow counselors to read assessments.',
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
                    Icon(Icons.assessment, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No Assessments Available',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No mental health assessments have been shared with counselors yet.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0), // Extra bottom padding
              itemCount: assessments.length,
              itemBuilder: (context, index) {
                try {
                  final assessment = assessments[index].data() as Map<String, dynamic>;
                  final List<dynamic> answers = assessment['answers'] ?? [];
                  final DateTime timestamp = (assessment['timestamp'] as Timestamp).toDate();
                  final String userId = assessment['userId'] as String;
                  
                  // Check if it's an alert (has concerning answers)
                  bool isAlert = answers.any((answer) {
                    final String answerText = answer['answer']?.toString().toLowerCase() ?? '';
                    return answerText == 'bad' || 
                           answerText == 'never' || 
                           answerText == 'not at all';
                  });
                  
                  // Format timestamp to a readable string
                  final String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(timestamp);

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      leading: isAlert 
                          ? Icon(Icons.warning_rounded, color: Colors.orange.shade700)
                          : null,
                      title: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return const Text('Loading student data...');
                          }

                          if (userSnapshot.hasError) {
                            return Text('Student ID: $userId');
                          }
                          
                          final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                          final String studentName = userData?['displayName'] ?? 'Student';
                          
                          return Text(
                            'Assessment from $studentName',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                      subtitle: Text('Submitted on $formattedDate'),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      childrenPadding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Mental Health Assessment Results:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        ...answers.map<Widget>((answer) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  answer['question'] ?? 'Question not available',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text('Answer: '),
                                    Chip(
                                      label: Text(
                                        answer['answer'] ?? 'No answer',
                                        style: TextStyle(
                                          color: _getAnswerColor(answer['answer'] ?? ''),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: _getAnswerColor(answer['answer'] ?? '').withOpacity(0.1),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.person),
                              label: const Text('View Student Profile'),
                              onPressed: () {
                                // TODO: Navigate to student profile
                              },
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.message),
                              label: const Text('Contact Student'),
                              onPressed: () {
                                // TODO: Implement contact action
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  return Card(
                    color: Colors.red.shade50,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error parsing assessment data: $e'),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
  
  Color _getAnswerColor(String answer) {
    switch (answer.toLowerCase()) {
      case 'never':
      case 'bad':
      case 'not at all':
        return Colors.red;
      case 'rarely':
        return Colors.orange;
      case 'sometimes':
        return Colors.amber;
      case 'often':
        return Colors.green;
      case 'always':
      case 'good':
      case 'very good':
      case 'excellent':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
