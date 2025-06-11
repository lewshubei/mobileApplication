import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'dart:math' as Math;

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
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'counselor')
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
            'Error loading counselors: ${snapshot.error}',
            style: TextStyle(color: Colors.red.shade400),
          );
        }

        final counselors = snapshot.data?.docs ?? [];

        if (counselors.isEmpty) {
          return const Text(
            'No counselors available',
            style: TextStyle(fontStyle: FontStyle.italic),
          );
        }

        String currentAssignmentText = 'Not assigned';

        if (selectedCounselorId != null) {
          // Use firstWhereOrNull instead of firstWhere with orElse
          final assignedCounselorDoc = counselors.firstWhereOrNull(
            (doc) => doc.id == selectedCounselorId,
          );

          if (assignedCounselorDoc != null) {
            final counselorData =
                assignedCounselorDoc.data() as Map<String, dynamic>?;
            if (counselorData != null) {
              currentAssignmentText =
                  'Assigned to: ${counselorData['name'] ?? counselorData['displayName'] ?? 'Unknown Counselor'}';
            }
          } else {
            // Handle case where counselor ID exists but counselor is not in list
            currentAssignmentText =
                'Assigned to counselor (ID: ${selectedCounselorId!.substring(0, Math.min(4, selectedCounselorId!.length))}...)';
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline, size: 20, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Counselor Assignment',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    currentAssignmentText,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color:
                          selectedCounselorId != null
                              ? Colors.teal.shade700
                              : Colors.grey.shade600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _showCounselorSelectionDialog(context, counselors);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade50,
                    foregroundColor: Colors.teal.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Assign'),
                ),
              ],
            ),
          ],
        );
      },
    );
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
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
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
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Chip(
                              label: Text(
                                answerText,
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: Colors.grey.shade100,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.red;
    if (score >= 60) return Colors.orange[800]!;
    if (score >= 40) return Colors.amber[800]!;
    return Colors.green[800]!;
  }

  String _getScoreDescription(double score) {
    if (score >= 80) return 'Needs attention - Consider speaking with a counselor';
    if (score >= 60) return 'Moderate mental wellbeing';
    if (score >= 40) return 'Good mental wellbeing';
    return 'Excellent mental wellbeing';
  }
}
