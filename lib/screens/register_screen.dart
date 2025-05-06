import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sentimo/screens/home_screen.dart';
import 'package:sentimo/screens/counselor_home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'student';
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        // Create user
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        // Save role to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'email': _emailController.text.trim(),
              'role': _selectedRole,
              'createdAt': FieldValue.serverTimestamp(),
            });

        if (!mounted) return;

        // Navigate by role
        if (_selectedRole == 'counselor') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CounselorHomeScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = e.message ?? 'Registration failed';
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Unexpected error occurred';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter email';
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Enter valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Enter password';
                      if (value.length < 6) return 'Minimum 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Select Role',
                      prefixIcon: Icon(Icons.person),
                    ),
                    items:
                        ['student', 'counselor']
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(
                                  role[0].toUpperCase() + role.substring(1),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() => _selectedRole = value!),
                  ),
                  const SizedBox(height: 24),

                  // Error
                  if (_errorMessage.isNotEmpty)
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),

                  // Register Button
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text('Register'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
