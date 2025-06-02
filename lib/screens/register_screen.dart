import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sentimo/providers/user_provider.dart';
import 'package:sentimo/screens/home_screen.dart';
import 'package:sentimo/screens/counselor_home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'student';
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isPasswordFocused = false;

  // Password strength properties
  String _strengthLevel = 'Very Weak';
  double _strengthPercentage = 0.25; // 25% filled bar

  @override
  void initState() {
    super.initState();
    // Add listener to password controller to update strength on changes
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordStrength);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Password strength evaluation logic
  void _updatePasswordStrength() {
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _strengthLevel = 'Very Weak';
        _strengthPercentage = 0.25;
      });
      return;
    }

    // Check password strength based on various criteria
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecialChars = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

    // Calculate strength score (0-4)
    int strengthScore = 0;

    // Length criteria
    if (password.length >= 6) strengthScore++;

    // Character type combination criteria
    int typesCount = 0;
    if (hasUppercase) typesCount++;
    if (hasLowercase) typesCount++;
    if (hasDigits) typesCount++;
    if (hasSpecialChars) typesCount++;

    // Add score based on character variety
    if (typesCount >= 2) strengthScore++;
    if (typesCount >= 3) strengthScore++;
    if (typesCount >= 4) strengthScore++;

    // Set strength level and percentage based on score
    setState(() {
      if (strengthScore <= 1) {
        _strengthLevel = 'Very Weak';
        _strengthPercentage = 0.25;
      } else if (strengthScore == 2) {
        _strengthLevel = 'Weak';
        _strengthPercentage = 0.5;
      } else if (strengthScore == 3) {
        _strengthLevel = 'Good';
        _strengthPercentage = 0.75;
      } else {
        _strengthLevel = 'Strong';
        _strengthPercentage = 1.0;
      }
    });

    // Validate the form when password changes
    // This will update any error messages
    if (_formKey.currentState != null) {
      _formKey.currentState!.validate();
    }
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

        // Update user provider with the logged-in user
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(userCredential.user);

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

  // Get color based on strength level
  Color _getStrengthColor() {
    switch (_strengthLevel) {
      case 'Very Weak':
        return Colors.red;
      case 'Weak':
        return Colors.orange;
      case 'Good':
        return Colors.yellow;
      case 'Strong':
        return Colors.green;
      default:
        return Colors.red;
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
            child: Column(
              children: [
                // Logo
                Image.asset('assets/images/logo.png', height: 180, width: 180),
                const SizedBox(height: 24),

                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
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
                          if (value == null || value.isEmpty) {
                            return 'Enter email';
                          }
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
                      Focus(
                        onFocusChange: (hasFocus) {
                          setState(() {
                            _isPasswordFocused = hasFocus;
                          });
                        },
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter password';
                            }
                            if (value.length < 6) return 'Minimum 6 characters';
                            return null;
                          },
                          onChanged: (_) {
                            // This ensures error messages update on every keystroke
                            if (_formKey.currentState != null) {
                              _formKey.currentState!.validate();
                            }
                          },
                        ),
                      ),

                      // Password Strength Indicator
                      if (_isPasswordFocused) ...[
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _strengthPercentage,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getStrengthColor(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _strengthLevel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _getStrengthColor(),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      
                      // Confirm Password
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
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
                      SizedBox(
                        width: double.infinity, // Full width button
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ), // Adjusted padding instead of fixed height
                            minimumSize: const Size.fromHeight(
                              48,
                            ), // Standard form field height in Flutter
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                  : const Text(
                                    'Register',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
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
      ),
    );
  }
}
