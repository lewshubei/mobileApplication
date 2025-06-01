import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AssessmentDetailScreen extends StatelessWidget {
  final String assessmentId;
  final String studentId;

  const AssessmentDetailScreen({
    Key? key,
    required this.assessmentId,
    required this.studentId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Details'),
      ),
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
      future: FirebaseFirestore.instance.collection('users').doc(studentId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        final String studentName = userData?['name'] ?? 
                                  userData?['displayName'] ?? 
                                  'Student ${studentId.substring(0, 4)}';
        
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssessmentSection(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('user_assessments').doc(assessmentId).get(),
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
        final DateTime timestamp = (assessmentData['timestamp'] as Timestamp).toDate();
        final String formattedDate = DateFormat('MMMM dd, yyyy - HH:mm').format(timestamp);
        final int totalQuestions = answers.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assessment info header - Full width
            SizedBox(
              width: double.infinity,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Questions and answers - Full width
            ...List.generate(answers.length, (index) {
              final answer = answers[index];
              final String question = answer['question'] ?? 'Question not available';
              final String answerText = answer['answer'] ?? 'No answer';
              final int questionNumber = index + 1;
              
              return SizedBox(
                width: double.infinity,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            const SizedBox(width: 38), // Align with question text
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
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
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
            
            // Action buttons
            SizedBox(
              width: double.infinity,
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.message),
                  label: const Text('Contact Student'),
                  onPressed: () {
                    // TODO: Implement contact action
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
