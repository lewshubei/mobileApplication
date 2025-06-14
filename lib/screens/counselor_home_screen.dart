import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:sentimo/screens/login_screen.dart';
import 'package:sentimo/screens/profile_screen.dart';
import 'package:sentimo/providers/user_provider.dart';
import 'package:sentimo/components/counselor/dashboard_component.dart';
import 'package:sentimo/components/counselor/mental_health_assessment_component.dart';
import 'package:sentimo/components/counselor/appointment_list_component.dart';

class CounselorHomeScreen extends StatefulWidget {
  const CounselorHomeScreen({super.key});

  @override
  State<CounselorHomeScreen> createState() => _CounselorHomeScreenState();
}

class _CounselorHomeScreenState extends State<CounselorHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Listen to tab changes to update floating action button visibility
    _tabController.addListener(() {
      // Call setState to rebuild the widget when tab changes
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        title: const Text('Counselor Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Appointments'),
            Tab(text: 'Assessments'),
          ],
        ),
      ),
      drawer: _buildCustomDrawer(context, user, theme),
      body: TabBarView(
        controller: _tabController,
        children: [
          const CounselorDashboardComponent(),
          const AppointmentListComponent(),
          MentalHealthAssessmentComponent(
            user: user,
            signOutCallback: _signOut,
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Create new appointment (to be implemented)')),
                );
              },
              child: const Icon(Icons.add),
              tooltip: 'Create New Appointment',
            )
          : null,
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
          // _buildMenuTile(
          //   context,
          //   icon: Icons.settings,
          //   title: 'Settings',
          //   onTap: () {},
          // ),
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
            user?.displayName ?? 'User',
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
