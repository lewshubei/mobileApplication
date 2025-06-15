import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminForumComponent extends StatefulWidget {
  const AdminForumComponent({super.key});

  @override
  State<AdminForumComponent> createState() => _AdminForumComponentState();
}

class _AdminForumComponentState extends State<AdminForumComponent> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(children: [_buildFilterSection(), _buildPostList()]),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Forum Posts',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showCreatePostDialog,
                tooltip: 'Create Post',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Posts', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Approved', 'approved'),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Rejected', 'rejected'),
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

  Widget _buildPostList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('forum_posts')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final posts = snapshot.data?.docs ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Icon(Icons.info_outline, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'No posts available.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (userSnapshot.hasError) {
              return Center(
                child: Text('Error loading users: ${userSnapshot.error}'),
              );
            }

            final users = {
              for (var doc in userSnapshot.data!.docs)
                doc.id:
                    (doc.data() as Map<String, dynamic>)['name'] ??
                    'Unknown User',
            };

            final filteredPosts =
                posts
                    .map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return {
                        'id': doc.id,
                        'title': data['title'] ?? 'Untitled',
                        'content': data['content'] ?? '',
                        'createdAt': data['createdAt'],
                        'approved': data['approved'] ?? false,
                        'rejected': data['rejected'] ?? false,
                        'authorId': data['authorId'],
                        'authorName': users[data['authorId']] ?? 'Unknown User',
                      };
                    })
                    .where((post) {
                      if (_selectedFilter == 'approved') {
                        return post['approved'] == true &&
                            post['rejected'] == false;
                      } else if (_selectedFilter == 'pending') {
                        return post['approved'] == false &&
                            post['rejected'] == false;
                      } else if (_selectedFilter == 'rejected') {
                        return post['rejected'] == true;
                      }
                      return true;
                    })
                    .toList();

            if (filteredPosts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Icon(Icons.info_outline, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No posts available.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredPosts.length,
              itemBuilder: (context, index) {
                final post = filteredPosts[index];
                return _buildPostCard(post);
              },
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> filterPosts(List<Map<String, dynamic>> posts) {
    if (_selectedFilter == 'approved') {
      return posts
          .where(
            (post) => post['approved'] == true && post['rejected'] == false,
          )
          .toList();
    } else if (_selectedFilter == 'pending') {
      return posts
          .where(
            (post) => post['approved'] == false && post['rejected'] == false,
          )
          .toList();
    } else if (_selectedFilter == 'rejected') {
      return posts.where((post) => post['rejected'] == true).toList();
    }
    return posts;
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    Color columnBackgroundColor;
    if (post['approved'] == true) {
      columnBackgroundColor = Colors.green.shade100;
    } else if (post['rejected'] == true) {
      columnBackgroundColor = Colors.red.shade100;
    } else {
      columnBackgroundColor = Colors.yellow.shade100;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: columnBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            spreadRadius: 1,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  post['title'] ?? 'Untitled',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_red_eye),
                onPressed: () {
                  _showPostDetailsDialog(post);
                },
                tooltip: 'View Post',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Posted by: ${post['authorName'] ?? 'Unknown User'}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            _formatTimestamp(post['createdAt']),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
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

                  // Title & Author & Date
                  Text(
                    post['title'] ?? 'Untitled',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Posted by: ${post['authorName'] ?? 'Unknown User'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(post['createdAt']),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // Content scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        post['content'] ?? '',
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status Badge
                  if (post['approved'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            post['approved'] == true
                                ? Colors.green.shade100
                                : post['rejected'] == true
                                ? Colors.red.shade100
                                : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            post['approved'] == true
                                ? Icons.check_circle
                                : post['rejected'] == true
                                ? Icons.cancel
                                : Icons.hourglass_empty,
                            size: 16,
                            color:
                                post['approved'] == true
                                    ? Colors.green
                                    : post['rejected'] == true
                                    ? Colors.red
                                    : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            post['approved'] == true
                                ? 'Approved'
                                : post['rejected'] == true
                                ? 'Rejected'
                                : 'Pending',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  post['approved'] == true
                                      ? Colors.green.shade800
                                      : post['rejected'] == true
                                      ? Colors.red.shade800
                                      : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),

                      // Approve with confirmation
                      ElevatedButton(
                        onPressed:
                            post['approved'] == true
                                ? null
                                : () {
                                  _confirmApproveDialog(post);
                                },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                        ),
                        child: const Text(
                          'Approve',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Reject with confirmation
                      ElevatedButton(
                        onPressed:
                            post['rejected'] == true
                                ? null
                                : () {
                                  _confirmRejectDialog(post);
                                },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 20,
                          ),
                        ),
                        child: const Text(
                          'Reject',
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

  void _confirmApproveDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Approval'),
          content: const Text('Are you sure you want to approve this post?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _updatePostStatus(post['id'], true);
                Navigator.pop(context); // close confirmation
                Navigator.pop(context); // close details dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Yes, Approve', style: TextStyle(fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  void _confirmRejectDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Rejection'),
          content: const Text('Are you sure you want to reject this post?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _updatePostStatus(post['id'], false);
                Navigator.pop(context); // close confirmation
                Navigator.pop(context); // close details dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Yes, Reject', style: TextStyle(fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updatePostStatus(String postId, bool approve) async {
    try {
      await FirebaseFirestore.instance
          .collection('forum_posts')
          .doc(postId)
          .update({'approved': approve, 'rejected': !approve});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating post status: $e')));
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showCreatePostDialog() {
    final TextEditingController _titleController = TextEditingController();
    final TextEditingController _contentController = TextEditingController();

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
                    controller: _titleController,
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
                    controller: _contentController,
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
                          final title = _titleController.text.trim();
                          final content = _contentController.text.trim();

                          if (title.isNotEmpty && content.isNotEmpty) {
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              final userRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user!.uid);
                              final userDoc = await userRef.get();
                              final userData =
                                  userDoc.data() as Map<String, dynamic>;

                              bool isAdmin =
                                  userData['role'] ==
                                  'admin'; // Check if role is admin

                              await FirebaseFirestore.instance
                                  .collection('forum_posts')
                                  .add({
                                    'title': title,
                                    'content': content,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'approved': isAdmin,
                                    'rejected': false,
                                    'authorId': user.uid,
                                    'role': 'admin',
                                  });

                              Navigator.pop(context);
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to post: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blue.shade600,
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
}
