import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sentimo/screens/login_screen.dart';
import 'package:sentimo/screens/profile_screen.dart';
import 'package:sentimo/providers/user_provider.dart';
import 'package:provider/provider.dart';

class CounselorHomeScreen extends StatelessWidget {
  const CounselorHomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user ?? FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Counselor Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Assessments'),
            ],
          ),
        ),
        drawer: _buildCustomDrawer(context, user, theme),
        body: TabBarView(
          children: [
            _buildDashboardTab(context),
            _buildAssessmentsTab(context, user),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // TODO: Implement action to view all students
          },
          tooltip: 'View all students',
          child: const Icon(Icons.people),
        ),
      ),
    );
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

  int min(int a, int b) {
    return a < b ? a : b;
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
                    onPressed: () => _signOut(context),
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

  Widget _buildCustomDrawer(BuildContext context, User? user, ThemeData theme) {
    return Drawer(
      width: 280,
      backgroundColor: theme.cardColor,
      elevation: 16,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(user, theme),
          _buildMenuTile(
            context,
            icon: Icons.person,
            title: 'Profile',
            onTap: () => _navigateTo(context, const ProfileScreen()),
          ),
          _buildMenuTile(
            context,
            icon: Icons.settings,
            title: 'Settings',
            onTap: () {},
          ),
          const Divider(height: 1, thickness: 1),
          _buildMenuTile(
            context,
            icon: Icons.logout,
            title: 'Logout',
            onTap: () => _signOut(context),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(User? user, ThemeData theme) {
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor,
            theme.primaryColorDark ?? theme.primaryColor,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withOpacity(0.3),
            backgroundImage:
                user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            onBackgroundImageError:
                user?.photoURL != null
                    ? (e, _) => debugPrint("Image load error: $e")
                    : null,
            child:
                user?.photoURL == null
                    ? const Icon(Icons.person, size: 36, color: Colors.white)
                    : null,
          ),
          const SizedBox(height: 12),
          Text(
            user?.displayName ?? 'User',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          Text(
            user?.email ?? 'Not logged in',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  ListTile _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color =
        isDestructive ? Colors.redAccent : Theme.of(context).iconTheme.color;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
      hoverColor: Colors.grey.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}
