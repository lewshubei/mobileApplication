import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:sentimo/providers/user_provider.dart';
import 'package:sentimo/screens/profile_screen.dart';
import 'package:sentimo/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mood_entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  DateTime _currentMonth = DateTime.now();
  bool _isLoadingMoodData = false;

  // Store mood data (now will be synced with Firebase)
  final Map<String, Map<String, dynamic>> _moodData = {};

  bool _showPieChart = false;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  // Mental Health Questions
  final List<Map<String, dynamic>> questions = [
    {
      'question': 'How often do you feel stressed?',
      'options': ['Never', 'Sometimes', 'Often', 'Always'],
    },
    {
      'question': 'Do you have trouble sleeping?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Frequently'],
    },
    {
      'question': 'How would you rate your mood recently?',
      'options': ['Good', 'Neutral', 'Bad', 'Very Bad'],
    },
    {
      'question': 'Do you feel overwhelmed by daily tasks?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often'],
    },
    {
      'question': 'How often do you feel anxious or nervous?',
      'options': ['Never', 'Sometimes', 'Often', 'All the time'],
    },
    {
      'question': 'Do you find it hard to concentrate?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often'],
    },
    {
      'question': 'How often do you feel lonely?',
      'options': ['Never', 'Sometimes', 'Often', 'Always'],
    },
    {
      'question': 'Do you feel satisfied with your personal relationships?',
      'options': ['Very Satisfied', 'Somewhat', 'Not Much', 'Not at All'],
    },
    {
      'question': 'Do you feel hopeful about the future?',
      'options': ['Always', 'Often', 'Rarely', 'Never'],
    },
    {
      'question': 'How often do you engage in activities you enjoy?',
      'options': ['Daily', 'Few times a week', 'Rarely', 'Never'],
    },
  ];

  // Add these methods for Firebase operations
  Future<void> _loadMoodDataFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in, cannot load mood data');
      return;
    }

    setState(() {
      _isLoadingMoodData = true;
    });

    try {
      print('Loading mood data for user: ${user.uid}');

      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('moods')
              .get();

      print('Found ${querySnapshot.docs.length} mood entries');

      setState(() {
        _moodData.clear();
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          print('Loading mood: ${doc.id} -> $data');
          _moodData[doc.id] = {
            'moodIndex': data['moodIndex'],
            'date': (data['date'] as Timestamp).toDate(),
            'category': data['category'] ?? 'General',
            'description': data['description'] ?? '',
          };
        }
        _isLoadingMoodData = false;
      });

      print('Loaded ${_moodData.length} mood entries into local storage');
    } catch (e) {
      print('Error loading mood data: $e');
      setState(() {
        _isLoadingMoodData = false;
      });

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load mood data: $e')));
      }
    }
  }

  Future<void> _saveMoodToFirebase(
    String moodKey,
    int moodIndex,
    DateTime date, {
    String category = 'General',
    String description = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in, cannot save mood data');
      return;
    }

    try {
      print(
        'Saving mood to Firebase: $moodKey -> moodIndex: $moodIndex, date: $date, category: $category, description: $description',
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('moods')
          .doc(moodKey)
          .set({
            'moodIndex': moodIndex,
            'date': Timestamp.fromDate(date),
            'category': category,
            'description': description,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      print('Successfully saved mood to Firebase');
    } catch (e) {
      print('Error saving mood data: $e');

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save mood: $e')));
      }
    }
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
  void initState() {
    super.initState();
    // Add a small delay to ensure Firebase Auth is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoodDataFromFirebase();
    });
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

              // Debug option to reload data
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reload Mood Data'),
                onTap: () {
                  Navigator.pop(context);
                  _loadMoodDataFromFirebase();
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
        title: Row(
          children: [
            const Text('Sentimo'),
            if (_isLoadingMoodData) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
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
    final existingData = _moodData[moodKey];

    // Initialize values with existing data or defaults
    int selectedMoodIndex =
        existingData?['moodIndex'] ?? 2; // Default to "Neutral"
    String selectedCategory = existingData?['category'] ?? 'General';
    String description = existingData?['description'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController descriptionController =
            TextEditingController(text: description);

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
                          const SizedBox(width: 48), // For balance
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

                      // Category selection
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            items: const [
                              DropdownMenuItem(
                                value: 'General',
                                child: Text('General'),
                              ),
                              DropdownMenuItem(
                                value: 'Work',
                                child: Text('Work'),
                              ),
                              DropdownMenuItem(
                                value: 'School',
                                child: Text('School'),
                              ),
                              DropdownMenuItem(
                                value: 'Home',
                                child: Text('Home'),
                              ),
                              DropdownMenuItem(
                                value: 'Relationships',
                                child: Text('Relationships'),
                              ),
                              DropdownMenuItem(
                                value: 'Health',
                                child: Text('Health'),
                              ),
                            ],
                            onChanged: (value) {
                              setDialogState(() {
                                selectedCategory = value!;
                              });
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Description field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description (optional)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Add any notes about your mood...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Action buttons
                      Row(
                        children: [
                          // Add a delete button if there's existing data
                          if (existingData != null)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  // Remove from local state
                                  setState(() {
                                    _moodData.remove(moodKey);
                                  });

                                  // Remove from Firebase
                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .collection('moods')
                                        .doc(moodKey)
                                        .delete();
                                  }

                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Mood entry deleted'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (existingData != null) const SizedBox(width: 16),
                          Expanded(
                            flex: existingData != null ? 1 : 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                // Save mood data locally first
                                setState(() {
                                  _moodData[moodKey] = {
                                    'moodIndex': selectedMoodIndex,
                                    'date': selectedDate,
                                    'category': selectedCategory,
                                    'description': descriptionController.text,
                                  };
                                });

                                Navigator.pop(context);

                                // Show immediate confirmation
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      existingData != null
                                          ? 'Mood updated: ${_getMoodLabel(selectedMoodIndex)}'
                                          : 'Mood saved: ${_getMoodLabel(selectedMoodIndex)}',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );

                                // Save to Firebase in background
                                await _saveMoodToFirebase(
                                  moodKey,
                                  selectedMoodIndex,
                                  selectedDate,
                                  category: selectedCategory,
                                  description: descriptionController.text,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                existingData != null ? 'Update' : 'Save',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
      },
    );
  }

  Widget _buildAnalysisPage(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue.shade600, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Mood Analysis',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Date Range Selector
            _buildDateRangeSelector(),
            const SizedBox(height: 24),

            // Analysis Content
            FutureBuilder<List<MoodAnalysisData>>(
              future: _getMoodDataForAnalysis(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading mood data',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  );
                }

                final allMoodData = snapshot.data ?? [];
                final filteredData =
                    _selectedStartDate != null && _selectedEndDate != null
                        ? MoodAnalyzer.filterByDateRange(
                          allMoodData,
                          _selectedStartDate!,
                          _selectedEndDate!,
                        )
                        : allMoodData;

                if (filteredData.isEmpty) {
                  return _buildEmptyAnalysisState();
                }

                return _buildAnalysisContent(filteredData);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForumPage(BuildContext context) {
    return const Center(
      child: Text('Forum Page', style: TextStyle(fontSize: 24)),
    );
  }

  Widget _buildMentalHealthTestPage(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
                          _showAssessmentDialog(context);
                          // ScaffoldMessenger.of(context).showSnackBar(
                          //   const SnackBar(
                          //     content: Text('Assessment feature coming soon!'),
                          //   ),
                          // );
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Previous Results',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload',
                  onPressed: () {
                    setState(
                      () {},
                    ); // Triggers a rebuild and refreshes the FutureBuilder
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            FutureBuilder<List<QueryDocumentSnapshot>>(
              future: _getUserAssessments(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading results',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  );
                }

                final assessments = snapshot.data ?? [];

                if (assessments.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildAssessmentList(assessments);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentList(List<QueryDocumentSnapshot> assessments) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assessments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final assessment = assessments[index].data() as Map<String, dynamic>;
        final timestamp = assessment['timestamp'] as Timestamp?;
        final shared = assessment['shared_with_counselor'] ?? false;
        final answers = assessment['answers'] as List<dynamic>;
        final totalCount = assessments.length;

        return Card(
          color: _getAssessmentRiskColor(assessment['score'] ?? 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showAssessmentDetails(context, assessment),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Assessment ${totalCount - index}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (shared) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.share, color: Colors.green, size: 18),
                          ],
                        ],
                      ),
                      if (assessment['score'] != null)
                        Text(
                          '${assessment['score'].toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _getAssessmentRiskTextColor(assessment['score'] ?? 0),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (timestamp != null)
                    Text(
                      DateFormat(
                        'MMM dd, yyyy - hh:mm a',
                      ).format(timestamp.toDate()),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    '${answers.length} questions answered',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAssessmentDetails(
    BuildContext context,
    Map<String, dynamic> assessment,
  ) {
    final answers = assessment['answers'] as List<dynamic>;
    final timestamp = assessment['timestamp'] as Timestamp?;
    final shared = assessment['shared_with_counselor'] ?? false;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7, // 固定高度
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assessment Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (timestamp != null)
                            Text(
                              'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate())}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          if (shared)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.share,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Shared with counselor',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          ...answers.map(
                            (qa) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    qa['question'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    qa['answer'] ?? 'No answer',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showAssessmentDialog(BuildContext context) {
    int currentIndex = 0;
    List<String?> selectedAnswers = List.filled(questions.length, null);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final currentQuestion = questions[currentIndex];

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(
                          Icons.psychology_alt_rounded,
                          color: Colors.green,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Question ${currentIndex + 1} of ${questions.length}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Question
                    Text(
                      currentQuestion['question'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Options
                    ...List<Widget>.generate(
                      currentQuestion['options'].length,
                      (index) {
                        final option = currentQuestion['options'][index];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color:
                                  selectedAnswers[currentIndex] == option
                                      ? Colors.green
                                      : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: RadioListTile<String>(
                            value: option,
                            groupValue: selectedAnswers[currentIndex],
                            onChanged: (value) {
                              setState(() {
                                selectedAnswers[currentIndex] = value;
                              });
                            },
                            title: Text(option),
                            activeColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Navigation buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            if (currentIndex == 0) {
                              Navigator.of(context).pop();
                            } else {
                              setState(() => currentIndex--);
                            }
                          },
                          icon: Icon(
                            currentIndex == 0 ? Icons.close : Icons.arrow_back,
                            color: Colors.grey[700],
                          ),
                          label: Text(currentIndex == 0 ? 'Cancel' : 'Back'),
                        ),
                        ElevatedButton.icon(
                          onPressed:
                              selectedAnswers[currentIndex] == null
                                  ? null
                                  : () {
                                    if (currentIndex < questions.length - 1) {
                                      setState(() => currentIndex++);
                                    } else {
                                      Navigator.of(context).pop();
                                      _showFinishDialog(
                                        context,
                                        selectedAnswers,
                                      );
                                    }
                                  },
                          icon: Icon(
                            currentIndex < questions.length - 1
                                ? Icons.arrow_forward
                                : Icons.check,
                          ),
                          label: Text(
                            currentIndex < questions.length - 1
                                ? 'Next'
                                : 'Finish',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFinishDialog(
    BuildContext context,
    List<String?> selectedAnswers,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to save your assessment results.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('user id: ${user.uid}');

    // Calculate score based on answers
    int totalScore = 0;
    for (int i = 0; i < questions.length; i++) {
      final answer = selectedAnswers[i];
      if (answer != null) {
        // Score based on answer position (0-3)
        final answerIndex = questions[i]['options'].indexOf(answer);
        // Higher index means more positive answer
        totalScore = totalScore + (answerIndex as int);
      }
    }
    
    // Calculate percentage score (max possible score is 3 * number of questions)
    final maxPossibleScore = 3 * questions.length;
    final percentageScore = (totalScore / maxPossibleScore) * 100;

    final assessmentData = {
      'userId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'answers': List.generate(
        questions.length,
        (i) => {
          'question': questions[i]['question'],
          'answer': selectedAnswers[i],
        },
      ),
      'score': percentageScore, // Add score to the assessment data
    };

    final shouldShare = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 40,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, color: Colors.green, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Send Results to Counselor?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Would you like to share your assessment results...',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(Icons.cancel, color: Colors.grey),
                            label: const Text('No, Thanks'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                            ),
                            label: const Text('Yes, Send'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );

    // Save data into firestore
    try {
      final finalData = {
        ...assessmentData,
        'shared_with_counselor': shouldShare ?? false,
      };

      await FirebaseFirestore.instance
          .collection('user_assessments')
          .add(finalData);

      final message =
          shouldShare == true
              ? '✅ Your results were successfully shared with your counselor.'
              : '💾 Your results were saved privately and not shared.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Save failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<QueryDocumentSnapshot>> _getUserAssessments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('user_assessments')
              .where('userId', isEqualTo: user.uid)
              .orderBy('timestamp', descending: true)
              .get();

      return querySnapshot.docs;
    } catch (e) {
      print('Error fetching assessments: $e');
      return [];
    }
  }

  Widget _buildDateRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analysis Period',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                    'Start Date',
                    _selectedStartDate,
                    () => _selectStartDate(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateButton(
                    'End Date',
                    _selectedEndDate,
                    () => _selectEndDate(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQuickDateButton(
                  'Last 7 days',
                  () => _setQuickDateRange(7),
                ),
                const SizedBox(width: 8),
                _buildQuickDateButton(
                  'Last 30 days',
                  () => _setQuickDateRange(30),
                ),
                const SizedBox(width: 8),
                _buildQuickDateButton('All time', () => _clearDateRange()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? DateFormat('MMM dd, yyyy').format(date)
                  : 'Select date',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateButton(String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _selectedStartDate ??
          DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedStartDate = date;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? DateTime.now(),
      firstDate: _selectedStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedEndDate = date;
      });
    }
  }

  void _setQuickDateRange(int days) {
    setState(() {
      _selectedEndDate = DateTime.now();
      _selectedStartDate = DateTime.now().subtract(Duration(days: days));
    });
  }

  void _clearDateRange() {
    setState(() {
      _selectedStartDate = null;
      _selectedEndDate = null;
    });
  }

  Future<List<MoodAnalysisData>> _getMoodDataForAnalysis() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('moods')
              .orderBy('date', descending: false)
              .get();

      return querySnapshot.docs.map((doc) {
        return MoodAnalysisData.fromFirestore(doc.id, doc.data());
      }).toList();
    } catch (e) {
      print('Error fetching mood data for analysis: $e');
      return [];
    }
  }

  Widget _buildEmptyAnalysisState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mood_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No mood data found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start tracking your mood to see analysis',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisContent(List<MoodAnalysisData> data) {
    final mostCommon = MoodAnalyzer.getMostCommonMood(data);
    final distribution = MoodAnalyzer.getMoodDistribution(data);
    final average = MoodAnalyzer.getAverageMoodScore(data);
    final categoryStats = MoodAnalyzer.getCategoryAnalysis(data);
    final insights = MoodAnalyzer.generateInsights(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards
        _buildSummaryCards(data, mostCommon, average),
        const SizedBox(height: 24),

        // Mood Distribution
        _buildMoodDistributionCard(distribution),
        const SizedBox(height: 24),

        // Category Analysis
        if (categoryStats.isNotEmpty) ...[
          _buildCategoryAnalysisCard(categoryStats),
          const SizedBox(height: 24),
        ],

        // Insights
        _buildInsightsCard(insights),
      ],
    );
  }

  Widget _buildSummaryCards(
    List<MoodAnalysisData> data,
    MoodStats? mostCommon,
    double average,
  ) {
    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Total \nEntries',
            data.length.toString(),
            Icons.calendar_today,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Average Mood',
            '${average.toStringAsFixed(1)}/4',
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Most Common',
            mostCommon?.emoji ?? '🙂',
            Icons.emoji_emotions,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodDistributionCard(List<MoodStats> distribution) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mood Distribution',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.bar_chart,
                        color:
                            !_showPieChart ? Colors.blue.shade600 : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _showPieChart = false;
                        });
                      },
                      tooltip: 'Bar Chart',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.pie_chart,
                        color:
                            _showPieChart ? Colors.blue.shade600 : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _showPieChart = true;
                        });
                      },
                      tooltip: 'Pie Chart',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child:
                  _showPieChart
                      ? _buildPieChart(distribution)
                      : _buildBarChart(distribution),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(List<MoodStats> distribution) {
    final nonZeroDistribution =
        distribution.where((mood) => mood.count > 0).toList();

    if (nonZeroDistribution.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No mood data to display',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sections:
                  nonZeroDistribution.map((mood) {
                    return PieChartSectionData(
                      color: MoodAnalyzer.moodColors[mood.moodIndex],
                      value: mood.percentage,
                      title: '${mood.percentage.toStringAsFixed(1)}%',
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 30),
        // Legend
        Wrap(
          spacing: 20,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children:
              nonZeroDistribution.map((mood) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: MoodAnalyzer.moodColors[mood.moodIndex],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${mood.emoji} ${mood.label}',
                        style: const TextStyle(
                          fontSize: 13, // Slightly larger font
                          fontWeight:
                              FontWeight
                                  .w500, // Medium weight for better readability
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<MoodStats> distribution) {
    return Column(
      children:
          distribution.map((mood) => _buildMoodDistributionItem(mood)).toList(),
    );
  }

  Widget _buildMoodDistributionItem(MoodStats mood) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Text(mood.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      mood.label,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${mood.count} (${mood.percentage.toStringAsFixed(1)}%)',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: mood.percentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    MoodAnalyzer.moodColors[mood.moodIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAnalysisCard(List<CategoryStats> categoryStats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mood by Category',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...categoryStats.map((category) => _buildCategoryItem(category)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(CategoryStats category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MoodAnalyzer
                  .moodColors[category.averageScore.round().clamp(0, 4)]
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                category.averageEmoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.category,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${category.averageLabel} (${category.averageScore.toStringAsFixed(1)}/4) • ${category.count} entries',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(List<String> insights) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber.shade600),
                const SizedBox(width: 8),
                Text(
                  'Key Insights',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...insights.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getAssessmentRiskColor(num score) {
    // High score = high risk = red, medium = yellow, low = green
    if (score >= 80) return Colors.red.shade100;
    if (score >= 60) return Colors.yellow.shade100;
    return Colors.green.shade100;
  }

  Color _getAssessmentRiskTextColor(num score) {
    if (score >= 80) return Colors.red;
    if (score >= 60) return Colors.orange[800]!;
    return Colors.green[800]!;
  }
}
