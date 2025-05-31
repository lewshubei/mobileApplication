import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
          child: const Icon(Icons.people),
        ),
      ),
    );
  }
  
  Widget _buildDashboardTab(BuildContext context) {
    // Dashboard content unchanged
    return SafeArea(
      child: Padding(
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
                    '24',
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Alerts',
                    '3',
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
                    '7.2',
                    Icons.mood,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Reports',
                    '12',
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

            Expanded(
              child: ListView(
                children: const [
                  _ActivityItem(
                    name: 'John Doe',
                    action: 'logged mood',
                    value: 'Sad (3/10)',
                    time: '10 minutes ago',
                    isAlert: true,
                  ),
                  _ActivityItem(
                    name: 'Jane Smith',
                    action: 'logged mood',
                    value: 'Happy (8/10)',
                    time: '25 minutes ago',
                    isAlert: false,
                  ),
                  _ActivityItem(
                    name: 'Mike Johnson',
                    action: 'logged mood',
                    value: 'Anxious (4/10)',
                    time: '1 hour ago',
                    isAlert: true,
                  ),
                  _ActivityItem(
                    name: 'Sarah Williams',
                    action: 'logged mood',
                    value: 'Content (7/10)',
                    time: '2 hours ago',
                    isAlert: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
              padding: const EdgeInsets.all(16.0),
              itemCount: assessments.length,
              itemBuilder: (context, index) {
                try {
                  final assessment = assessments[index].data() as Map<String, dynamic>;
                  final List<dynamic> answers = assessment['answers'] ?? [];
                  final DateTime timestamp = (assessment['timestamp'] as Timestamp).toDate();
                  final String userId = assessment['userId'] as String;
                  
                  // Format timestamp to a readable string
                  final String formattedDate = '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
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

  // Rest of the code (buildStatCard, buildCustomDrawer, etc.) remains unchanged
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

class _ActivityItem extends StatelessWidget {
  final String name;
  final String action;
  final String value;
  final String time;
  final bool isAlert;

  const _ActivityItem({
    required this.name,
    required this.action,
    required this.value,
    required this.time,
    required this.isAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isAlert ? 2 : 0,
      color: isAlert ? Colors.orange.shade50 : null,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side:
            isAlert
                ? BorderSide(color: Colors.orange.shade200, width: 1)
                : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(child: Text(name.substring(0, 1))),
        title: Text(name),
        subtitle: Text('$action: $value'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (isAlert)
              const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
          ],
        ),
        onTap: () {
          // TODO: Implement action to view student details
        },
      ),
    );
  }
}
