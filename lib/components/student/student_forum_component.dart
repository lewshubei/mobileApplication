import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentForumComponent extends StatefulWidget {
  const StudentForumComponent({super.key});

  @override
  State<StudentForumComponent> createState() => _StudentForumComponentState();
}

class _StudentForumComponentState extends State<StudentForumComponent> {
  void _showCreatePostDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController contentController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Post',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter title here',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Content',
                      hintText: 'Enter content here',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final title = titleController.text.trim();
                          final content = contentController.text.trim();

                          if (title.isNotEmpty && content.isNotEmpty) {
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              final userRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user!.uid);
                              final userDoc = await userRef.get();
                              final userData =
                                  userDoc.data() as Map<String, dynamic>;
                              final role = userData['role'] ?? 'student';

                              await FirebaseFirestore.instance
                                  .collection('forum_posts')
                                  .add({
                                    'title': title,
                                    'content': content,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'approved': false,
                                    'rejected': false,
                                    'authorId': user.uid,
                                    'role': role,
                                  });

                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder:
                                    (context) => Dialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Post Submitted',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 16),

                                            Text(
                                              'Your post has been submitted and is pending admin approval.',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey.shade700,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 24),

                                            ElevatedButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              style: ElevatedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                backgroundColor:
                                                    Colors.green.shade600,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: const Text(
                                                'OK',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              );
                            } catch (e) {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder:
                                    (context) => Dialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Title
                                            Text(
                                              'Post Submission Failed',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 16),

                                            Text(
                                              'Failed to post: $e',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey.shade700,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 24),

                                            ElevatedButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              style: ElevatedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                backgroundColor:
                                                    Colors.red.shade600,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: const Text(
                                                'OK',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 24,
                          ),
                        ),
                        child: const Text(
                          'Post',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showPostDetailsDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Post Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),

                  // Title
                  Text(
                    post['title'] ?? 'Untitled',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Posted by + Timestamp
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Posted by: ${post['authorName'] ?? 'Unknown User'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        _formatTimestamp(post['createdAt']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        post['content'] ?? '',
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Close button only
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 20,
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forum',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Create Post Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.forum,
                          color: Colors.green.shade600,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Got something to share?',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: Colors.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Engage with the community by posting your thoughts, experiences, or concerns. All posts will be reviewed by admins before approval.',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _showCreatePostDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'Create a New Post',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'All Posts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            // Posts with authorName mapping
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('forum_posts')
                      .where('approved', isEqualTo: true)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, postSnapshot) {
                if (postSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (postSnapshot.hasError) {
                  return Text('Error loading posts: ${postSnapshot.error}');
                }

                final posts = postSnapshot.data?.docs ?? [];

                return StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('users')
                          .snapshots(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (userSnapshot.hasError) {
                      return Text('Error loading users: ${userSnapshot.error}');
                    }

                    final users = {
                      for (var doc in userSnapshot.data!.docs)
                        doc.id:
                            (doc.data() as Map<String, dynamic>)['name'] ??
                            'Unknown User',
                    };

                    final postList =
                        posts.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final authorId = data['authorId'];
                          final role = data['role'] ?? 'student';

                          return {
                            'id': doc.id,
                            'title': data['title'] ?? '',
                            'content': data['content'] ?? '',
                            'createdAt': data['createdAt'],
                            'authorId': authorId,
                            'authorName':
                                role == 'admin'
                                    ? (users[authorId] ?? 'Admin')
                                    : 'anonymous',
                          };
                        }).toList();

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: postList.length,
                      itemBuilder: (context, index) {
                        final post = postList[index];
                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: ListTile(
                            onTap: () => _showPostDetailsDialog(post),
                            title: Text(
                              post['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post['content']),
                                const SizedBox(height: 6),
                                Text(
                                  'Posted by ${post['authorName']} on ${_formatTimestamp(post['createdAt'])}',
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
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
