import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sentimo/models/user_role.dart';
import 'package:sentimo/screens/login_screen.dart';
import 'package:sentimo/screens/home_screen.dart';
import 'package:sentimo/screens/counselor_home_screen.dart';
import 'package:sentimo/services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentimo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          secondary: Colors.pinkAccent,
        ),
        fontFamily: 'Poppins',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.teal, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// Updated AuthWrapper to handle role-based navigation
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the snapshot has user data, then they're already signed in
        if (snapshot.hasData && snapshot.data != null) {
          print("User is signed in: ${snapshot.data?.displayName}");
          return FutureBuilder<UserRole>(
            future: UserService().getCurrentUserRole(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                // Show loading indicator while fetching role
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // Navigate based on role
              final role = roleSnapshot.data ?? UserRole.student;
              if (role == UserRole.counselor) {
                return const CounselorHomeScreen();
              } else {
                return const HomeScreen();
              }
            },
          );
        }

        // Otherwise, they're not signed in
        print("User is not signed in");
        return const LoginScreen();
      },
    );
  }
}
