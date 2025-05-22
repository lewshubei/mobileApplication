import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sentimo/providers/user_provider.dart';
import 'package:sentimo/screens/login_screen.dart';
import 'package:sentimo/screens/profile_screen.dart';

class HomeScreen extends StatelessWidget {
<<<<<<< HEAD
  const HomeScreen({Key? key}) : super(key: key);
=======
  const HomeScreen({super.key});
>>>>>>> 1fafbdee2eb3e97ce0b5945aa92cd4dbf0759bba
  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user ?? FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentimo'),
        automaticallyImplyLeading: true,
      ),
      drawer: _buildCustomDrawer(context, user, theme),
      body: _buildHomeBody(context, user, theme),
    );
  }

  Widget _buildCustomDrawer(BuildContext context, User? user, ThemeData theme) {
    return Drawer(
      width: 280,
      backgroundColor: theme.cardColor,
      elevation: 16,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(user, theme),
          _buildMenuTile(
            context,
            icon: Icons.person,
            title: 'Profile',
            onTap: () => _navigateTo(context, const ProfileScreen()),
          ),
          _buildMenuTile(
            context,
            icon: Icons.settings,
            title: 'Settings',
            onTap: () {},
          ),
          const Divider(height: 1, thickness: 1),
          _buildMenuTile(
            context,
            icon: Icons.logout,
            title: 'Logout',
            onTap: () => _signOut(context),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(User? user, ThemeData theme) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final currentUser = userProvider.user ?? user;
        // print('Avatar URL: ${userProvider.avatarUrl}');
        // print('Photo URL: ${user?.photoURL}');
        return DrawerHeader(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.primaryColor,
                theme.primaryColorDark ?? theme.primaryColor,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withOpacity(0.3),
                backgroundImage:
                    userProvider.avatarUrl != null
                        ? NetworkImage(userProvider.avatarUrl!)
                        : (user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null),
                onBackgroundImageError:
                    userProvider.avatarUrl != null || user?.photoURL != null
                        ? (e, _) => print("Image load error: $e")
                        : null,
                child:
                    userProvider.avatarUrl == null && user?.photoURL == null
                        ? Icon(Icons.person, size: 36, color: Colors.white)
                        : null,
              ),
              const SizedBox(height: 12),
              Text(
                currentUser?.displayName ?? 'User',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              Text(
                currentUser?.email ?? 'Not logged in',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  ListTile _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color =
        isDestructive ? Colors.redAccent : Theme.of(context).iconTheme.color;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
      hoverColor: Colors.red.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildHomeBody(BuildContext context, User? user, ThemeData theme) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final currentUser = userProvider.user ?? user;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Welcome to Sentimo', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                currentUser?.displayName ?? currentUser?.email ?? 'User',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              const Text(
                'This is a placeholder for the mood tracker dashboard.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
