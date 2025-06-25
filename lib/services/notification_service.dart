import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppNotification {
  final String quote;
  final DateTime dateTime;
  final bool seen;
  final String type; // Added type field

  AppNotification({
    required this.quote, 
    required this.dateTime, 
    this.seen = false,
    this.type = 'quote', // Default type
  });

  Map<String, dynamic> toJson() => {
    'quote': quote,
    'dateTime': dateTime.toIso8601String(),
    'seen': seen,
    'type': type,
  };

  static AppNotification fromJson(Map<String, dynamic> json) => AppNotification(
    quote: json['quote'],
    dateTime: DateTime.parse(json['dateTime']),
    seen: json['seen'] ?? false,
    type: json['type'] ?? 'quote',
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleDailyQuoteNotification() async {
    final quote = await fetchRandomQuote();
    await _saveNotification(quote, DateTime.now(), type: 'quote');
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Daily Motivation',
      quote,
      _nextInstanceOf8AM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_quote_channel',
          'Daily Quotes',
          channelDescription: 'Daily motivational quotes at 8 AM',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf8AM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<String> fetchRandomQuote() async {
    try {
      final response = await http.get(Uri.parse('https://zenquotes.io/api/random'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data[0]['q'] + ' — ' + data[0]['a'];
      } else {
        return 'Stay positive and keep moving forward!';
      }
    } catch (e) {
      return 'Stay positive and keep moving forward!';
    }
  }

  // --- Bad Mood Detection ---
  Future<void> checkAndNotifyBadMoodStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get the last 7 days of mood data to have enough context
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 7));
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('moods')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: false)
          .get();

      if (querySnapshot.docs.length < 3) return; // Need at least 3 days

      // Convert to a list of mood entries with dates
      List<MapEntry<DateTime, int>> moodEntries = querySnapshot.docs.map((doc) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final moodIndex = data['moodIndex'] as int;
        return MapEntry(date, moodIndex);
      }).toList();

      // Sort by date to ensure proper ordering
      moodEntries.sort((a, b) => a.key.compareTo(b.key));

      // Check for 3 consecutive bad mood days
      bool hasConsecutiveBadDays = false;
      DateTime streakStartDate = DateTime.now();
      
      for (int i = 0; i <= moodEntries.length - 3; i++) {
        bool isConsecutive = true;
        DateTime firstDate = moodEntries[i].key;
        
        // Check if we have 3 consecutive days with bad mood (0=Angry, 1=Sad)
        for (int j = 0; j < 3; j++) {
          final currentEntry = moodEntries[i + j];
          final expectedDate = firstDate.add(Duration(days: j));
          
          // Check if dates are consecutive and mood is bad
          if (!_isSameDay(currentEntry.key, expectedDate) || 
              !_isBadMood(currentEntry.value)) {
            isConsecutive = false;
            break;
          }
        }
        
        if (isConsecutive) {
          hasConsecutiveBadDays = true;
          streakStartDate = firstDate;
          break;
        }
      }

      if (hasConsecutiveBadDays) {
        // Check if we already sent a notification for this streak period
        final hasRecentNotification = await _hasRecentBadMoodNotification(streakStartDate);
        
        if (!hasRecentNotification) {
          await _sendBadMoodNotification();
        }
      }
    } catch (e) {
      print('Error checking bad mood streak: $e');
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  bool _isBadMood(int moodIndex) {
    return moodIndex == 0 || moodIndex == 1; // Angry or Sad
  }

  Future<bool> _hasRecentBadMoodNotification(DateTime streakStartDate) async {
    final notifications = await getNotifications();
    
    // Check if there's a bad mood notification within the last 7 days
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
    
    return notifications.any((notification) => 
      notification.type == 'bad_mood_streak' &&
      notification.dateTime.isAfter(cutoffDate)
    );
  }

  Future<void> _sendBadMoodNotification() async {
    const String message = "We've noticed you've been feeling down for a few days. "
        "Consider taking our mental health assessment to get personalized support and resources.";
    
    // Save notification locally
    await _saveNotification(message, DateTime.now(), type: 'bad_mood_streak');
    
    // Send local push notification
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      'Mental Health Check-in',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mental_health_channel',
          'Mental Health Notifications',
          channelDescription: 'Notifications for mental health check-ins and assessments',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
    
    print('Bad mood streak notification sent');
  }

  // --- Local Notification Storage ---
  static const String _notifKey = 'app_notifications';

  Future<List<AppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_notifKey) ?? [];
    return jsonList.map((e) => AppNotification.fromJson(jsonDecode(e))).toList();
  }

  Future<void> _saveNotification(String quote, DateTime dateTime, {String type = 'quote'}) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = await getNotifications();
    notifications.insert(0, AppNotification(
      quote: quote, 
      dateTime: dateTime, 
      seen: false,
      type: type,
    ));
    
    // Keep only the last 50 notifications to prevent storage bloat
    if (notifications.length > 50) {
      notifications.removeRange(50, notifications.length);
    }
    
    final jsonList = notifications.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_notifKey, jsonList);
  }

  Future<void> markAllAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = await getNotifications();
    final updated = notifications.map((n) => AppNotification(
      quote: n.quote, 
      dateTime: n.dateTime, 
      seen: true,
      type: n.type,
    )).toList();
    final jsonList = updated.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_notifKey, jsonList);
  }

  Future<bool> hasUnseenNotifications() async {
    final notifications = await getNotifications();
    return notifications.any((n) => !n.seen);
  }
}
