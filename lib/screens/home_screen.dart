import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:sentimo/providers/user_provider.dart';
import 'package:sentimo/screens/profile_screen.dart';
import 'package:sentimo/screens/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  DateTime _currentMonth = DateTime.now();

  // Store mood data (in real app, this would come from database)
  final Map<String, Map<String, dynamic>> _moodData = {};

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 3) {
      // Show mental health test page instead of profile options
      setState(() {
        _selectedIndex = index;
      });
      _pageController.jumpToPage(index);
    } else {
      setState(() {
        _selectedIndex = index;
      });
      _pageController.jumpToPage(index);
    }
  }

  void _showProfileOptions(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user ?? FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User info at the top
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // User avatar
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                      child:
                          user?.photoURL == null
                              ? const Icon(
                                Icons.person,
                                size: 30,
                                color: Colors.grey,
                              )
                              : null,
                    ),
                    const SizedBox(width: 16),
                    // User name and email
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'User',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Profile option
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('View Profile'),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
              ),

              // Settings option
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to settings page
                  // For now, just show a snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings page coming soon')),
                  );
                },
              ),

              // Logout option
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red.shade400),
                title: Text(
                  'Logout',
                  style: TextStyle(color: Colors.red.shade400),
                ),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  _signOut(
                    context,
                  ); // Use the new _signOut method instead of _logout
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Separate logout function for clarity
  Future<void> _logout(BuildContext context) async {
    // Show confirmation dialog
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      'Logout',
                      style: TextStyle(color: Colors.red.shade400),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (shouldLogout) {
      try {
        // Get a reference to the UserProvider before any async operations
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        // First clear the user from provider
        userProvider.setUser(null);

        // Then sign out from Firebase
        await FirebaseAuth.instance.signOut();

        // Only after successful logout, navigate to login screen
        if (context.mounted) {
          // Use pushReplacement instead of pushAndRemoveUntil for a simpler approach
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } catch (e) {
        print('Error during logout: $e');
        // Only show error if context is still valid
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
        }
      }
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  String _getMoodKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentimo'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        actions: [
          // Add user profile icon in the app bar
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _showProfileOptions(context),
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildMoodTrackerPage(context),
          _buildAnalysisPage(context),
          _buildForumPage(context),
          _buildMentalHealthTestPage(
            context,
          ), // Changed from Container() to a new test page
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Mood',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Analysis',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Forum'),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.psychology,
            ), // Changed from Icons.person to Icons.psychology
            label: 'Test', // Changed from 'Profile' to 'Test'
          ),
        ],
      ),
    );
  }

  Widget _buildMoodTrackerPage(BuildContext context) {
    final dateFormat = DateFormat('MMM yyyy');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Month navigation
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 28),
                    onPressed: _previousMonth,
                    padding: EdgeInsets.zero,
                  ),
                  Text(
                    dateFormat.format(_currentMonth),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 28),
                    onPressed: _nextMonth,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            // Weekday headers
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (index) {
                  final weekdays = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ];
                  return SizedBox(
                    width: 40,
                    child: Text(
                      weekdays[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Calendar grid - using Expanded to take remaining space
            Expanded(child: _buildSimpleCalendarGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCalendarGrid() {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    );

    // Calculate first day of the week (0 = Monday)
    int firstWeekday = firstDayOfMonth.weekday - 1;
    final daysInMonth = lastDayOfMonth.day;

    // Calculate rows needed
    final rowCount = ((daysInMonth + firstWeekday) / 7).ceil();

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: rowCount,
      itemBuilder: (context, rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (colIndex) {
              final dayIndex = rowIndex * 7 + colIndex;
              final day = dayIndex - firstWeekday + 1;

              if (day < 1 || day > daysInMonth) {
                return const SizedBox(width: 40);
              }

              final currentDate = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                day,
              );
              final today = DateTime.now();
              final isToday =
                  currentDate.year == today.year &&
                  currentDate.month == today.month &&
                  currentDate.day == today.day;

              final moodKey = _getMoodKey(currentDate);
              final hasMood = _moodData.containsKey(moodKey);

              // Generate a random mood index for demonstration
              final randomMoodIndex = (day * 17) % 5;

              // For demo purposes, let's say days before today have moods
              final hasRandomMood = day < today.day && day > today.day - 15;

              if (hasRandomMood && !hasMood && day < 30) {
                _moodData[moodKey] = {
                  'moodIndex': randomMoodIndex,
                  'date': currentDate,
                };
              }

              return GestureDetector(
                onTap: () {
                  _showMoodSelectionDialog(context, currentDate);
                },
                child: SizedBox(
                  width: 40,
                  child: Column(
                    children: [
                      // Mood circle
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:
                              hasMood
                                  ? _getMoodColor(
                                    _moodData[moodKey]!['moodIndex'],
                                  )
                                  : Colors.blue.shade100,
                          shape: BoxShape.circle,
                          border:
                              isToday
                                  ? Border.all(
                                    color: Colors.green.shade600,
                                    width: 2,
                                  )
                                  : null,
                        ),
                        child: Center(
                          child:
                              hasMood
                                  ? Text(
                                    _getMoodEmoji(
                                      _moodData[moodKey]!['moodIndex'],
                                    ),
                                    style: const TextStyle(fontSize: 18),
                                  )
                                  : Icon(
                                    Icons.add,
                                    color: Colors.blue.shade300,
                                    size: 14,
                                  ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Day number
                      Text(
                        day.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          color:
                              isToday ? Colors.green.shade700 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Color _getMoodColor(int moodIndex) {
    final colors = [
      Colors.red.shade400, // Angry
      Colors.orange.shade400, // Sad
      Colors.lightGreen.shade400, // Neutral
      Colors.blue.shade400, // Happy
      Colors.purple.shade400, // Excellent
    ];
    return colors[moodIndex];
  }

  String _getMoodEmoji(int moodIndex) {
    final emojis = ['😠', '😔', '🙂', '😄', '😊'];
    return emojis[moodIndex];
  }

  String _getMoodLabel(int moodIndex) {
    final labels = ['Angry', 'Sad', 'Neutral', 'Happy', 'Excellent'];
    return labels[moodIndex];
  }

  void _showMoodSelectionDialog(BuildContext context, DateTime selectedDate) {
    final isToday =
        selectedDate.year == DateTime.now().year &&
        selectedDate.month == DateTime.now().month &&
        selectedDate.day == DateTime.now().day;

    // Check if we already have mood data for this date
    final moodKey = _getMoodKey(selectedDate);
    int selectedMoodIndex =
        _moodData.containsKey(moodKey)
            ? _moodData[moodKey]!['moodIndex']
            : 3; // Default to "Happy"

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Close button and date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                          ),
                          Text(
                            isToday
                                ? 'Today, ${DateFormat('MMM d').format(selectedDate)}'
                                : DateFormat('MMM d').format(selectedDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Question
                      Text(
                        isToday
                            ? 'How do you feel today?'
                            : 'How did you feel?',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 30),

                      // Mood emoji
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: _getMoodColor(selectedMoodIndex),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _getMoodEmoji(selectedMoodIndex),
                            style: const TextStyle(fontSize: 50),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Mood label
                      Text(
                        _getMoodLabel(selectedMoodIndex),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Mood selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedMoodIndex = index;
                              });
                            },
                            child: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: _getMoodColor(index),
                                shape: BoxShape.circle,
                                border:
                                    selectedMoodIndex == index
                                        ? Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        )
                                        : null,
                              ),
                              child: Center(
                                child: Text(
                                  _getMoodEmoji(index),
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 30),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // Save mood data
                            setState(() {
                              _moodData[moodKey] = {
                                'moodIndex': selectedMoodIndex,
                                'date': selectedDate,
                              };
                            });

                            Navigator.pop(context);

                            // Show confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Mood saved: ${_getMoodLabel(selectedMoodIndex)}',
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Save ${_getMoodLabel(selectedMoodIndex)}!',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnalysisPage(BuildContext context) {
    return const Center(
      child: Text('Analysis Page', style: TextStyle(fontSize: 24)),
    );
  }

  Widget _buildForumPage(BuildContext context) {
    return const Center(
      child: Text('Forum Page', style: TextStyle(fontSize: 24)),
    );
  }

  Widget _buildMentalHealthTestPage(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mental Health Assessment',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Test introduction card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          color: Colors.green.shade600,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'How are you feeling?',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Take a quick assessment to check your mental wellbeing. This test helps identify potential areas of concern and track your progress over time.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Start the assessment
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Assessment feature coming soon!'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Start Assessment',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Previous results section
            Text(
              'Previous Results',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Empty state or sample results
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.assessment_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No assessments taken yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete your first assessment to see results here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
