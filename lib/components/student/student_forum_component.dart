import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentForumComponent extends StatefulWidget {
  const StudentForumComponent({super.key});
  @override
  State<StudentForumComponent> createState() => _StudentForumComponentState();
}

class _StudentForumComponentState extends State<StudentForumComponent> {
  final List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _fetchApprovedPosts();
  }

  Future<void> _fetchApprovedPosts() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('forum_posts')
            .where('approved', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .get();

    final posts = snapshot.docs.map((doc) => doc.data()).toList();

    setState(() {
      _posts.clear();
      _posts.addAll(posts);
    });
  }

  void _showCreatePostDialog() {
    final TextEditingController _titleController = TextEditingController();
    final TextEditingController _contentController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create Forum Post'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = _titleController.text.trim();
                  final content = _contentController.text.trim();
                  final user = FirebaseAuth.instance.currentUser;

                  if (title.isNotEmpty && content.isNotEmpty && user != null) {
                    final userDoc =
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .get();
                    final role = userDoc.data()?['role'] ?? 'student';

                    await FirebaseFirestore.instance
                        .collection('forum_posts')
                        .add({
                          'title': title,
                          'content': content,
                          'createdAt': FieldValue.serverTimestamp(),
                          'approved': false,
                          'authorId': user.uid,
                          'role': role,
                        });

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Post submitted and pending admin approval.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum'),
        actions: [
          IconButton(
            onPressed: _showCreatePostDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Create Post',
          ),
        ],
      ),
      body:
          _posts.isEmpty
              ? const Center(child: Text('No approved posts yet.'))
              : ListView.builder(
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(
                        post['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post['content'] ?? ''),
                          const SizedBox(height: 6),
                          Text(
                            'Posted on ${_formatTimestamp(post['createdAt'])}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
