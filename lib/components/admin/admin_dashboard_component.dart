import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:sentimo/providers/user_provider.dart';

class AdminDashboardComponent extends StatelessWidget {
  const AdminDashboardComponent({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, usersSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('user_assessments')
                    .snapshots(),
            builder: (context, assessmentsSnapshot) {
              // Calculate dashboard stats
              int totalUsers = 0;
              int studentCount = 0;
              int counselorCount = 0;
              int adminCount = 0;
              int totalAssessments = 0;
              int assignedStudents = 0;
              int unassignedStudents = 0;

              // Process users data if available
              if (usersSnapshot.hasData) {
                final users = usersSnapshot.data!.docs;
                totalUsers = users.length - 1;

                for (var doc in users) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = data['role'] ?? 'student';

                  switch (role) {
                    case 'student':
                      studentCount++;
                      // Check if student is assigned to a counselor
                      if (data.containsKey('assignedCounselorId') &&
                          data['assignedCounselorId'] != null) {
                        assignedStudents++;
                      } else {
                        unassignedStudents++;
                      }
                      break;
                    case 'counselor':
                      counselorCount++;
                      break;
                    case 'admin':
                      adminCount++;
                      break;
                  }
                }
              }

              // Process assessments data if available
              if (assessmentsSnapshot.hasData) {
                totalAssessments = assessmentsSnapshot.data!.docs.length;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome section
                    FutureBuilder<DocumentSnapshot>(
                      future:
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser?.uid)
                              .get(),
                      builder: (context, adminSnapshot) {
                        String adminName =
                            Provider.of<UserProvider>(
                              context,
                            ).user?.displayName ??
                            FirebaseAuth.instance.currentUser?.displayName ??
                            FirebaseAuth.instance.currentUser?.email ??
                            'Admin';

                        if (adminSnapshot.hasData) {
                          final adminData =
                              adminSnapshot.data!.data()
                                  as Map<String, dynamic>?;
                          adminName =
                              adminData?['name'] ??
                              adminData?['displayName'] ??
                              adminName;
                        }

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings,
                                      color: Colors.purple.shade600,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Welcome, $adminName',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Manage student-counselor assignments and monitor system activity.',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // System Overview
                    Text(
                      'System Overview',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    // User stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Total Users',
                            totalUsers.toString(),
                            Icons.people,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Students',
                            studentCount.toString(),
                            Icons.school,
                            Colors.green,
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
                            'Counselors',
                            counselorCount.toString(),
                            Icons.psychology,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Assessments',
                            totalAssessments.toString(),
                            Icons.assessment,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Assignment Overview
                    Text(
                      'Student Assignment Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Assigned Students',
                            assignedStudents.toString(),
                            Icons.link,
                            Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Unassigned Students',
                            unassignedStudents.toString(),
                            Icons.link_off,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                Icons.assignment_ind,
                                color: Colors.blue.shade600,
                              ),
                              title: const Text('Manage Student Assignments'),
                              subtitle: const Text(
                                'Assign students to counselors',
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                // Switch to assignments tab
                                DefaultTabController.of(context).animateTo(1);
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: Icon(
                                Icons.people_outline,
                                color: Colors.green.shade600,
                              ),
                              title: const Text('View All Users'),
                              subtitle: const Text(
                                'Manage user accounts and roles',
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                // TODO: Navigate to user management
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'User management coming soon',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
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
