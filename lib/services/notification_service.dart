import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String quote;
  final DateTime dateTime;
  final bool seen;

  AppNotification({required this.quote, required this.dateTime, this.seen = false});

  Map<String, dynamic> toJson() => {
    'quote': quote,
    'dateTime': dateTime.toIso8601String(),
    'seen': seen,
  };

  static AppNotification fromJson(Map<String, dynamic> json) => AppNotification(
    quote: json['quote'],
    dateTime: DateTime.parse(json['dateTime']),
    seen: json['seen'] ?? false,
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
    await _saveNotification(quote, DateTime.now());
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

  // --- Local Notification Storage ---
  static const String _notifKey = 'app_notifications';

  Future<List<AppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_notifKey) ?? [];
    return jsonList.map((e) => AppNotification.fromJson(jsonDecode(e))).toList();
  }

  Future<void> _saveNotification(String quote, DateTime dateTime) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = await getNotifications();
    notifications.insert(0, AppNotification(quote: quote, dateTime: dateTime, seen: false));
    final jsonList = notifications.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_notifKey, jsonList);
  }

  Future<void> markAllAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = await getNotifications();
    final updated = notifications.map((n) => AppNotification(quote: n.quote, dateTime: n.dateTime, seen: true)).toList();
    final jsonList = updated.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_notifKey, jsonList);
  }

  Future<bool> hasUnseenNotifications() async {
    final notifications = await getNotifications();
    return notifications.any((n) => !n.seen);
  }
} 