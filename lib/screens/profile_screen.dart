import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sentimo/providers/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  String? _avatarBase64;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _loadAvatarFromFirestore();
  }

  Future<void> _loadAvatarFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (doc.exists) {
        setState(() {
          _avatarBase64 = doc.data()?['avatar'];
          _phoneController.text =
              doc.data()?['phoneNumber'] ?? user?.phoneNumber ?? '';
        });
      }
    } catch (e) {
      print('Error loading data from Firestore: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      final base64String = base64Encode(bytes);
      await _saveAvatarToFirestore(base64String);
    }
  }

  Future<void> _saveAvatarToFirestore(String base64Image) async {
    setState(() => _isSaving = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.updateAvatar(base64Image);

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully')),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user ?? FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileCard(context, user, isDarkMode),
            const SizedBox(height: 24),
            _isEditing ? _buildEditInfoCard() : _buildUserInfoCard(user, theme),
            const SizedBox(height: 20),
            _buildActionButtons(userProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, User? user, bool isDarkMode) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        gradient: LinearGradient(
          colors:
              isDarkMode
                  ? [Colors.purple.shade800, Colors.blue.shade900]
                  : [Colors.purple.shade200, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 68,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 65,
              backgroundImage:
                  _avatarBase64 != null
                      ? MemoryImage(base64Decode(_avatarBase64!))
                      : (user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null),
              child:
                  _avatarBase64 == null && user?.photoURL == null
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
                      : null,
            ),
          ),
          if (_isEditing)
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildEditInfoRow(Icons.person, 'Name', _nameController),
            const Divider(height: 30, thickness: 0.5),
            _buildEditInfoRow(Icons.phone, 'Phone Number', _phoneController),
          ],
        ),
      ),
    );
  }

  Widget _buildEditInfoRow(
    IconData icon,
    String label,
    TextEditingController controller,
  ) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade600),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: controller,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(UserProvider userProvider) {
    return _isEditing
        ? Column(
          children: [
            FilledButton(
              onPressed:
                  _isSaving
                      ? null
                      : () async {
                        await _saveChanges(userProvider);
                      },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.green.shade600,
              ),
              child:
                  _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16),
                      ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed:
                  _isSaving ? null : () => setState(() => _isEditing = false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: Colors.red.shade600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.red.shade600, fontSize: 16),
              ),
            ),
          ],
        )
        : FilledButton(
          onPressed: () => setState(() => _isEditing = true),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.blue.shade600,
          ),
          child: const Text('Edit Profile', style: TextStyle(fontSize: 16)),
        );
  }

  Future<void> _saveChanges(UserProvider userProvider) async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'phoneNumber': _phoneController.text,
        }, SetOptions(merge: true));

        await userProvider.refreshUser();
        await userProvider.updatePhoneNumber(_phoneController.text);
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: ${e.toString()}')),
      );
    }
  }

  Widget _buildUserInfoCard(User? user, ThemeData theme) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoRow(Icons.person, 'Name', user?.displayName ?? '-'),
                const Divider(height: 30),
                _buildInfoRow(Icons.email, 'Email', user?.email ?? '-'),
                const Divider(height: 30),
                _buildInfoRow(
                  Icons.phone,
                  'Phone Number',
                  userProvider.phoneNumber ?? '-',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade600),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}
