import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:sentimo/providers/user_provider.dart';
import 'package:intl/intl.dart';

class AdminDashboardComponent extends StatelessWidget {
  const AdminDashboardComponent({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade50, Colors.grey.shade100],
          ),
        ),
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
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.purple.shade50,
                                    Colors.purple.shade100,
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade100,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.admin_panel_settings,
                                            color: Colors.purple.shade700,
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Welcome back,',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      color:
                                                          Colors
                                                              .purple
                                                              .shade700,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                adminName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors
                                                              .purple
                                                              .shade900,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: Colors.purple.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Manage student-counselor assignments and monitor system activity.',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.copyWith(
                                                color: Colors.purple.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // System Overview
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.dashboard_outlined,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'System Overview',
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

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

                      // High Risk Assessments List
                      Text(
                        'Assessments',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (assessmentsSnapshot.hasData && assessmentsSnapshot.data!.docs.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: assessmentsSnapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final assessments = assessmentsSnapshot.data!.docs.toList();
                            // Sort by score descending
                            assessments.sort((a, b) {
                              final aScore = (a.data() as Map<String, dynamic>)['score'] ?? 0;
                              final bScore = (b.data() as Map<String, dynamic>)['score'] ?? 0;
                              return bScore.compareTo(aScore);
                            });
                            final assessment = assessments[index];
                            final data = assessment.data() as Map<String, dynamic>;
                            final score = data['score'] ?? 0;
                            final userId = data['userId'] ?? '';
                            final timestamp = data['timestamp'] as Timestamp?;
                            final dateStr = timestamp != null ? DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate()) : '';
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                              builder: (context, userSnapshot) {
                                String studentName = 'Student';
                                if (userSnapshot.hasData && userSnapshot.data != null) {
                                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                                  studentName = userData?['name'] ?? userData?['displayName'] ?? 'Student';
                                }
                                return Card(
                                  color: _getAssessmentRiskColor(score),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text(
                                          '${score.toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _getAssessmentRiskTextColor(score),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(dateStr),
                                  ),
                                );
                              },
                            );
                          },
                        )
                      else
                        const Text('No assessments found.'),

                      const SizedBox(height: 24),

                      // Quick Actions
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),

                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, Colors.grey.shade50],
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildQuickActionTile(
                                context,
                                icon: Icons.assignment_ind,
                                iconColor: Colors.blue,
                                title: 'Manage Student Assignments',
                                subtitle: 'Assign students to counselors',
                                onTap: () {
                                  DefaultTabController.of(context).animateTo(1);
                                },
                              ),
                              Divider(height: 1, color: Colors.grey.shade200),
                              _buildQuickActionTile(
                                context,
                                icon: Icons.people_outline,
                                iconColor: Colors.green,
                                title: 'View All Users',
                                subtitle: 'Manage user accounts and roles',
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'User management coming soon',
                                      ),
                                      behavior: SnackBarBehavior.floating,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on Color {
  get shade900 => null;

  get shade700 => null;
}

Color _getAssessmentRiskColor(num score) {
  if (score >= 80) return Colors.red.shade100;
  if (score >= 60) return Colors.orange.shade100;
  if (score >= 40) return Colors.amber.shade100;
  return Colors.green.shade100;
}

Color _getAssessmentRiskTextColor(num score) {
  if (score >= 80) return Colors.red;
  if (score >= 60) return Colors.orange[800]!;
  if (score >= 40) return Colors.amber[800]!;
  return Colors.green[800]!;
}

String getScoreDescription(num score) {
  if (score >= 80) return 'Needs attention - Consider speaking with a counselor';
  if (score >= 60) return 'Moderat mental wellbeing';
  if (score >= 40) return 'Good mental wellbeing';
  return 'Excellent mental wellbeing';
}
