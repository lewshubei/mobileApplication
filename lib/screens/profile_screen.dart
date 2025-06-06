import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sentimo/providers/user_provider.dart';
import 'package:sentimo/services/cloudinary_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isSaving = false;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  String? _avatarUrl;
  String? _currentUserId;

  FilePickerResult? _filePickerResult;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _currentUserId = user?.uid;
    _loadAvatarFromFirestore();

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null && mounted) {
        setState(() {
          _nameController.text = user.displayName ?? '';
          _phoneController.text = user.phoneNumber ?? '';
          _currentUserId = user.uid;
        });
        _loadAvatarFromFirestore();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.user ?? FirebaseAuth.instance.currentUser;

    if (currentUser?.uid != _currentUserId) {
      _nameController.text = currentUser?.displayName ?? '';
      _phoneController.text = currentUser?.phoneNumber ?? '';
      _currentUserId = currentUser?.uid;
      _loadAvatarFromFirestore();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _openFilePicker() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      allowedExtensions: ["jpg", "jpeg", "png"],
      type: FileType.custom,
    );
    setState(() {
      _filePickerResult = result;
    });
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

      if (mounted) {
        final data = doc.data();
        final firestoreAvatar = data?['avatarUrl'];
        final fallbackPhotoURL = user.photoURL;

        setState(() {
          _avatarUrl = firestoreAvatar ?? fallbackPhotoURL;
          _phoneController.text =
              data?['phoneNumber'] ?? user.phoneNumber ?? '';
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
      try {
        final file = File(pickedFile.path);
        final filePickerResult = FilePickerResult([
          PlatformFile(
            path: pickedFile.path,
            name: pickedFile.path.split('/').last,
            size: await file.length(),
          ),
        ]);

        final imageUrl = await uploadToCloudinary(filePickerResult);

        if (imageUrl != null) {
          await _saveAvatarToFirestore(imageUrl);
        }
      } catch (e) {
        print('Error processing image: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      }
    }
  }

  Future<void> _removeAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _avatarUrl = null;
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'avatarUrl': FieldValue.delete()},
      );

      await user.updatePhotoURL(null);

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.refreshUser();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture removed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove profile picture: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAvatarToFirestore(String imageUrl) async {
    setState(() => _isSaving = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePhotoURL(imageUrl);
        await user.reload();
      }

      await userProvider.updateAvatar(imageUrl);
      await userProvider.refreshUser();

      setState(() {
        _avatarUrl = imageUrl;
        _isSaving = false;
      });

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

  String? _validatePhoneNumber(String? value) {
    final cleaned = value?.replaceAll(RegExp(r'\D'), '') ?? '';

    // If length is insufficient or does not start with '01', it's invalid
    if (!cleaned.startsWith('01') || cleaned.length < 10) {
      return 'Please enter a valid Malaysian phone number.';
    }

    // If number starts with 011 (should be 11 digits)
    if (cleaned.startsWith('011')) {
      if (cleaned.length != 11) {
        return 'Phone numbers starting with 011 must have 11 digits.';
      }
    } else {
      // Other 01X numbers must have exactly 10 digits
      if (cleaned.length != 10) {
        return 'This phone number must have exactly 10 digits.';
      }

      // Check if the prefix is a valid Malaysian telco code
      final validPrefixes = [
        '010',
        '012',
        '013',
        '014',
        '016',
        '017',
        '018',
        '019',
      ];
      final prefix = cleaned.substring(0, 3);
      if (!validPrefixes.contains(prefix)) {
        return 'Please enter a valid Malaysian mobile number.';
      }
    }

    return null; // Passed validation
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

  void _showAvatarOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage();
                },
              ),
              if (_avatarUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _removeAvatar();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(BuildContext context, User? user, bool isDarkMode) {
    print('_avatarUrl: $_avatarUrl');

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
                  _avatarUrl != null
                      ? NetworkImage(_avatarUrl!)
                      : (user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null),
              child:
                  _avatarUrl == null && user?.photoURL == null
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
                      : null,
            ),
          ),
          if (_isEditing)
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  _showAvatarOptions(context);
                },
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
          // if (_isEditing && _avatarUrl != null)
          //   Positioned(
          //     right: 15,
          //     top: 0,
          //     child: GestureDetector(
          //       onTap: _removeAvatar,
          //       child: Container(
          //         padding: const EdgeInsets.all(4),
          //         decoration: BoxDecoration(
          //           color: Colors.red.shade600,
          //           shape: BoxShape.circle,
          //           border: Border.all(color: Colors.white, width: 1.5),
          //         ),
          //         child: const Icon(
          //           Icons.close_rounded,
          //           size: 16,
          //           color: Colors.white,
          //         ),
          //       ),
          //     ),
          //   ),
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
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildEditInfoRow(Icons.person, 'Name', _nameController),
              const Divider(height: 30, thickness: 0.5),
              _buildEditInfoRow(Icons.phone, 'Phone Number', _phoneController),
            ],
          ),
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
              TextFormField(
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
                keyboardType:
                    label == 'Phone Number'
                        ? TextInputType.phone
                        : TextInputType.text,
                inputFormatters:
                    label == 'Phone Number'
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : [],
                validator:
                    label == 'Phone Number' ? _validatePhoneNumber : null,
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
                  _isSaving
                      ? null
                      : () {
                        final user = FirebaseAuth.instance.currentUser;
                        setState(() {
                          _nameController.text = user?.displayName ?? '';
                          _phoneController.text =
                              userProvider.phoneNumber ?? '';
                          _isEditing = false;
                        });
                      },
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

    if (!_formKey.currentState!.validate()) {
      setState(() => _isSaving = false);
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await Future.wait([
          user.updateDisplayName(_nameController.text),
          FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': _nameController.text,
            'phoneNumber': _phoneController.text,
          }, SetOptions(merge: true)),
        ]);

        await userProvider.refreshUser();

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
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.user ?? FirebaseAuth.instance.currentUser;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoRow(
              Icons.person,
              'Name',
              currentUser?.displayName ?? '-',
            ),
            const Divider(height: 30),
            _buildInfoRow(Icons.email, 'Email', currentUser?.email ?? '-'),
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
