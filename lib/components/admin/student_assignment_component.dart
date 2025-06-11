import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
//import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentAssignmentComponent extends StatefulWidget {
  const StudentAssignmentComponent({super.key});

  @override
  State<StudentAssignmentComponent> createState() =>
      _StudentAssignmentComponentState();
}

class _StudentAssignmentComponentState
    extends State<StudentAssignmentComponent> {
  String _selectedFilter = 'all'; // all, assigned, unassigned, with_assessments
  bool _isAssigning = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Filter section
          _buildFilterSection(),

          // Students list
          Expanded(child: _buildStudentsList()),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Assignments',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Students', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Assigned', 'assigned'),
                const SizedBox(width: 8),
                _buildFilterChip('Unassigned', 'unassigned'),
                const SizedBox(width: 8),
                _buildFilterChip('With Assessments', 'with_assessments'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade700,
    );
  }

  Widget _buildStudentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .snapshots(),
      builder: (context, studentsSnapshot) {
        if (studentsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (studentsSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading students: ${studentsSnapshot.error}'),
              ],
            ),
          );
        }

        final allStudents = studentsSnapshot.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('user_assessments')
                  .snapshots(),
          builder: (context, assessmentsSnapshot) {
            final assessments = assessmentsSnapshot.data?.docs ?? [];

            // Group assessments by userId
            final Map<String, List<DocumentSnapshot>> studentAssessments = {};
            for (var assessment in assessments) {
              final data = assessment.data() as Map<String, dynamic>;
              final userId = data['userId'] as String;
              studentAssessments.putIfAbsent(userId, () => []).add(assessment);
            }

            // Filter students based on selected filter
            List<DocumentSnapshot> filteredStudents =
                allStudents.where((student) {
                  final studentData = student.data() as Map<String, dynamic>;
                  final hasAssignedCounselor =
                      studentData.containsKey('assignedCounselorId') &&
                      studentData['assignedCounselorId'] != null;
                  final hasAssessments = studentAssessments.containsKey(
                    student.id,
                  );

                  switch (_selectedFilter) {
                    case 'assigned':
                      return hasAssignedCounselor;
                    case 'unassigned':
                      return !hasAssignedCounselor;
                    case 'with_assessments':
                      return hasAssessments;
                    case 'all':
                    default:
                      return true;
                  }
                }).toList();

            // Sort students by their highest assessment score (descending)
            filteredStudents.sort((a, b) {
              final aAssessments = studentAssessments[a.id] ?? [];
              final bAssessments = studentAssessments[b.id] ?? [];
              final aHighest = aAssessments.isNotEmpty
                  ? (aAssessments.map((doc) => (doc.data() as Map<String, dynamic>)['score'] ?? 0).reduce((v, e) => v > e ? v : e))
                  : 0;
              final bHighest = bAssessments.isNotEmpty
                  ? (bAssessments.map((doc) => (doc.data() as Map<String, dynamic>)['score'] ?? 0).reduce((v, e) => v > e ? v : e))
                  : 0;
              return bHighest.compareTo(aHighest);
            });

            if (filteredStudents.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              itemCount: filteredStudents.length,
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                final studentData = student.data() as Map<String, dynamic>;
                final studentAssessmentsList =
                    studentAssessments[student.id] ?? [];

                return _buildStudentCard(
                  context,
                  student,
                  studentData,
                  studentAssessmentsList,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    String message;
    switch (_selectedFilter) {
      case 'assigned':
        message = 'No assigned students found';
        break;
      case 'unassigned':
        message = 'No unassigned students found';
        break;
      case 'with_assessments':
        message = 'No students with assessments found';
        break;
      default:
        message = 'No students found';
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(
    BuildContext context,
    DocumentSnapshot student,
    Map<String, dynamic> studentData,
    List<DocumentSnapshot> assessments,
  ) {
    final studentName =
        studentData['name'] ??
        studentData['displayName'] ??
        'Student ${student.id.substring(0, 4)}';
    final studentEmail = studentData['email'] ?? '';
    final assignedCounselorId = studentData['assignedCounselorId'];
    final assignedCounselorName = studentData['assignedCounselorName'];

    // Get latest assessment date and highest score
    DateTime? latestAssessmentDate;
    num? highestScore;
    if (assessments.isNotEmpty) {
      final sortedAssessments =
          assessments.toList()..sort((a, b) {
            final aScore = (a.data() as Map<String, dynamic>)['score'] ?? 0;
            final bScore = (b.data() as Map<String, dynamic>)['score'] ?? 0;
            return bScore.compareTo(aScore); // Descending by score
          });

      final highestData = sortedAssessments.first.data() as Map<String, dynamic>;
      highestScore = highestData['score'];
      latestAssessmentDate = (highestData['timestamp'] as Timestamp).toDate();
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student info row
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (studentEmail.isNotEmpty)
                        Text(
                          studentEmail,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                // Assessment count badge
                if (assessments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${assessments.length} assessment${assessments.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Assessment info
            if (latestAssessmentDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Latest assessment: ${DateFormat('MMM dd, yyyy').format(latestAssessmentDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (highestScore != null) ...[
                      const SizedBox(width: 16),
                      Text(
                        'Score: ${highestScore.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getAssessmentRiskTextColor(highestScore!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Assignment section
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    assignedCounselorId != null
                        ? 'Assigned to: ${assignedCounselorName ?? 'Unknown Counselor'}'
                        : 'Not assigned to any counselor',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          assignedCounselorId != null
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      _isAssigning
                          ? null
                          : () {
                            _showCounselorAssignmentDialog(
                              context,
                              student.id,
                              studentName,
                            );
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    assignedCounselorId != null ? 'Reassign' : 'Assign',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCounselorAssignmentDialog(
    BuildContext context,
    String studentId,
    String studentName,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assign Counselor',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a counselor for $studentName',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),

                Flexible(
                  child: StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('users')
                            .where('role', isEqualTo: 'counselor')
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Text(
                          'Error loading counselors: ${snapshot.error}',
                        );
                      }

                      final counselors = snapshot.data?.docs ?? [];

                      if (counselors.isEmpty) {
                        return const Center(
                          child: Text('No counselors available'),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount:
                            counselors.length + 1, // +1 for unassign option
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            // Unassign option
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.shade100,
                                child: Icon(
                                  Icons.person_off,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              title: const Text('Unassign Counselor'),
                              subtitle: const Text('Remove current assignment'),
                              onTap: () {
                                Navigator.of(context).pop();
                                _unassignCounselor(studentId, studentName);
                              },
                            );
                          }

                          final counselor = counselors[index - 1];
                          final counselorData =
                              counselor.data() as Map<String, dynamic>;
                          final counselorName =
                              counselorData['name'] ??
                              counselorData['displayName'] ??
                              'Counselor ${counselor.id.substring(0, 4)}';
                          final counselorEmail = counselorData['email'] ?? '';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade100,
                              child: Text(
                                counselorName.isNotEmpty
                                    ? counselorName[0].toUpperCase()
                                    : 'C',
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(counselorName),
                            subtitle: Text(counselorEmail),
                            onTap: () {
                              Navigator.of(context).pop();
                              _assignCounselor(
                                studentId,
                                counselor.id,
                                counselorName,
                                studentName,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _assignCounselor(
    String studentId,
    String counselorId,
    String counselorName,
    String studentName,
  ) async {
    setState(() {
      _isAssigning = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .update({
            'assignedCounselorId': counselorId,
            'assignedCounselorName': counselorName,
            'assignmentDate': FieldValue.serverTimestamp(),
            'assignedBy': FirebaseAuth.instance.currentUser?.uid,
          });

      // Create assignment record
      await FirebaseFirestore.instance.collection('counselor_assignments').add({
        'studentId': studentId,
        'counselorId': counselorId,
        'counselorName': counselorName,
        'assignmentDate': FieldValue.serverTimestamp(),
        'assignedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$studentName assigned to $counselorName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning counselor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
        });
      }
    }
  }

  Future<void> _unassignCounselor(String studentId, String studentName) async {
    setState(() {
      _isAssigning = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .update({
            'assignedCounselorId': FieldValue.delete(),
            'assignedCounselorName': FieldValue.delete(),
            'assignmentDate': FieldValue.delete(),
            'assignedBy': FieldValue.delete(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$studentName unassigned from counselor'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unassigning counselor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
        });
      }
    }
  }

  Color _getAssessmentRiskTextColor(num score) {
    if (score >= 80) return Colors.red;
    if (score >= 60) return Colors.orange[800]!;
    return Colors.green[800]!;
  }
}
