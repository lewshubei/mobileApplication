import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sentimo/screens/login_screen.dart';
import 'package:sentimo/screens/profile_screen.dart';
import 'package:sentimo/providers/user_provider.dart';
import 'package:sentimo/components/admin/student_assignment_component.dart';
import 'package:sentimo/components/admin/admin_dashboard_component.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Dashboard'), Tab(text: 'Assign Student')],
          ),
        ),
        drawer: _buildCustomDrawer(context, user, theme),
        body: const TabBarView(
          children: [AdminDashboardComponent(), StudentAssignmentComponent()],
        ),
      ),
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
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColorDark],
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
                user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            onBackgroundImageError:
                user?.photoURL != null
                    ? (e, _) => debugPrint("Image load error: $e")
                    : null,
            child:
                user?.photoURL == null
                    ? const Icon(Icons.person, size: 36, color: Colors.white)
                    : null,
          ),
          const SizedBox(height: 12),
          Text(
            user?.displayName ?? 'Admin',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          Text(
            user?.email ?? 'Not logged in',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
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
      hoverColor: Colors.grey.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}
