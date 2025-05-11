import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sentimo/screens/login_screen.dart';

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
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Counselor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
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
                        user?.displayName ?? user?.email ?? 'User',
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement action to view all students
        },
        child: const Icon(Icons.people),
      ),
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
