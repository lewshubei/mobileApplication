import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:sentimo/providers/user_provider.dart';

class CounselorDashboardComponent extends StatelessWidget {
  const CounselorDashboardComponent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildDashboardTab(context);
  }
  
  Widget _buildDashboardTab(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, usersSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('user_assessments')
                .where('shared_with_counselor', isEqualTo: true)
                .snapshots(),
            builder: (context, assessmentsSnapshot) {
              // Calculate dashboard stats
              int studentCount = 0;
              int alertCount = 0;
              double avgMood = 0;
              int reportCount = 0;
              List<Map<String, dynamic>> recentActivities = [];
              
              // Process users data if available
              if (usersSnapshot.hasData) {
                studentCount = usersSnapshot.data!.docs
                    .where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['role'] == 'student';
                    }).length;
              }
              
              // Process assessments data if available
              if (assessmentsSnapshot.hasData) {
                final assessments = assessmentsSnapshot.data!.docs;
                reportCount = assessments.length;
                
                // Calculate alerts (assessments with concerning answers)
                alertCount = assessments.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final List<dynamic> answers = data['answers'] ?? [];
                  // Count as alert if any answer is "bad", "never", or "not at all"
                  return answers.any((answer) {
                    final String answerText = answer['answer']?.toString().toLowerCase() ?? '';
                    return answerText == 'bad' || 
                           answerText == 'never' || 
                           answerText == 'not at all';
                  });
                }).length;
                
                // Calculate average mood (simplified example)
                double moodSum = 0;
                int moodCount = 0;
                
                for (var doc in assessments) {
                  final data = doc.data() as Map<String, dynamic>;
                  final List<dynamic> answers = data['answers'] ?? [];
                  
                  // Look for mood-related questions and assign numerical values
                  for (var answer in answers) {
                    final String question = answer['question']?.toString().toLowerCase() ?? '';
                    final String answerText = answer['answer']?.toString().toLowerCase() ?? '';
                    
                    if (question.contains('mood') || question.contains('feel')) {
                      double score = 5.0; // Default middle score
                      
                      if (answerText == 'bad' || answerText == 'never' || answerText == 'not at all') {
                        score = 2.0;
                      } else if (answerText == 'rarely') {
                        score = 4.0;
                      } else if (answerText == 'sometimes') {
                        score = 6.0;
                      } else if (answerText == 'often') {
                        score = 8.0;
                      } else if (answerText == 'always' || answerText == 'excellent') {
                        score = 10.0;
                      }
                      
                      moodSum += score;
                      moodCount++;
                    }
                  }
                }
                
                if (moodCount > 0) {
                  avgMood = moodSum / moodCount;
                }
                
                // Get recent activities
                final sortedAssessments = List<DocumentSnapshot>.from(assessments);
                sortedAssessments.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['timestamp'] as Timestamp;
                  final bTime = bData['timestamp'] as Timestamp;
                  return bTime.compareTo(aTime);
                });
                
                for (int i = 0; i < min(sortedAssessments.length, 5); i++) {
                  final data = sortedAssessments[i].data() as Map<String, dynamic>;
                  final List<dynamic> answers = data['answers'] ?? [];
                  final Timestamp timestamp = data['timestamp'] as Timestamp;
                  final String userId = data['userId'] as String;
                  
                  // Check if it's an alert
                  bool isAlert = answers.any((answer) {
                    final String answerText = answer['answer']?.toString().toLowerCase() ?? '';
                    return answerText == 'bad' || 
                           answerText == 'never' || 
                           answerText == 'not at all';
                  });
                  
                  recentActivities.add({
                    'userId': userId,
                    'type': 'assessment',
                    'timestamp': timestamp,
                    'isAlert': isAlert,
                  });
                }
              }
              
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome section
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
                            Text(
                              'Welcome, Counselor',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              Provider.of<UserProvider>(context).user?.displayName ?? 
                              FirebaseAuth.instance.currentUser?.displayName ?? 
                              FirebaseAuth.instance.currentUser?.email ?? 
                              'User',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'You can view and manage student mood data from this dashboard.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Stats overview
                    Text('Overview', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    
                    // Stats cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Students',
                            studentCount.toString(),
                            Icons.people,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Alerts',
                            alertCount.toString(),
                            Icons.warning_amber,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Avg. Mood',
                            avgMood.toStringAsFixed(1),
                            Icons.mood,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Reports',
                            reportCount.toString(),
                            Icons.assessment,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Recent activity
                    Text(
                      'Recent Activity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    
                    // Show loading indicator if data is still loading
                    if (usersSnapshot.connectionState == ConnectionState.waiting || 
                        assessmentsSnapshot.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator()),
                      
                    // Show error if any
                    if (usersSnapshot.hasError || assessmentsSnapshot.hasError)
                      Card(
                        color: Colors.red.shade50,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('Error loading data: ${usersSnapshot.error ?? assessmentsSnapshot.error}'),
                        ),
                      ),
                      
                    // Show no activities message if needed
                    if (recentActivities.isEmpty && 
                        !(usersSnapshot.connectionState == ConnectionState.waiting) && 
                        !(assessmentsSnapshot.connectionState == ConnectionState.waiting))
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No recent activity to display'),
                        ),
                      ),
                      
                    // List of recent activities
                    ...recentActivities.map((activity) {
                      return _buildActivityCard(context, activity);
                    }).toList(),
                    
                    // Add extra space at bottom to prevent FAB overlap
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildActivityCard(BuildContext context, Map<String, dynamic> activity) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(activity['userId']).get(),
      builder: (context, userSnapshot) {
        String name = 'Student';
        if (userSnapshot.hasData) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          name = userData?['displayName'] ?? 'Student';
        }
        
        final timestamp = activity['timestamp'] as Timestamp;
        final now = DateTime.now();
        final assessmentTime = timestamp.toDate();
        final difference = now.difference(assessmentTime);
        
        String timeAgo;
        if (difference.inMinutes < 1) {
          timeAgo = 'just now';
        } else if (difference.inHours < 1) {
          timeAgo = '${difference.inMinutes} min ago';
        } else if (difference.inDays < 1) {
          timeAgo = '${difference.inHours} hr ago';
        } else {
          timeAgo = '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
        }
        
        final isAlert = activity['isAlert'] as bool;
        
        return Card(
          elevation: 1,
          surfaceTintColor: isAlert ? Colors.orange.shade50 : null,
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isAlert
                ? BorderSide(color: Colors.orange.shade300, width: 1)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () {
              // TODO: Navigate to assessment details
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Avatar and status indicator
                  Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.teal.shade200,
                        radius: 24,
                        child: Text(
                          name.isNotEmpty ? name.substring(0, 1) : 'S',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (isAlert)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.warning_rounded,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (isAlert)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8, 
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Needs Attention',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Submitted mental health assessment',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  
                  // Timestamp
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
  
  int min(int a, int b) {
    return a < b ? a : b;
  }
}
