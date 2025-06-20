import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sentimo/screens/login_screen.dart';
import 'package:sentimo/screens/home_screen.dart';
import 'package:sentimo/providers/user_provider.dart';
import 'package:sentimo/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      child: MaterialApp(
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
      ),
    );
  }
}

// Add this new class to handle authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          userProvider.updateUser(snapshot.data);
        });
        // If the snapshot has user data, then they're already signed in
        if (snapshot.hasData && snapshot.data != null) {
          print("User is signed in: ${snapshot.data?.displayName}");
          return const HomeScreen();
        }

        // Otherwise, they're not signed in
        print("User is not signed in");
        return const LoginScreen();
      },
    );
  }
}

Future<void> sendAppointmentNotificationToStudent({
  required String studentId,
  required String counselorName,
  required DateTime appointmentDateTime,
}) async {
  final message = "You have an appointment with Counselor $counselorName on "
      "${DateFormat('MMM dd, yyyy – hh:mm a').format(appointmentDateTime)}.";

  await FirebaseFirestore.instance.collection('notifications').add({
    'userId': studentId,
    'message': message,
    'timestamp': FieldValue.serverTimestamp(),
    'seen': false,
  });
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> scheduleAppointmentReminder(DateTime appointmentDateTime, String counselorName) async {
  final reminderTime = appointmentDateTime.subtract(const Duration(days: 1));
  if (reminderTime.isBefore(DateTime.now())) return; // Don't schedule past reminders

  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    'Appointment Reminder',
    'You have an appointment with $counselorName tomorrow at ${DateFormat('hh:mm a').format(appointmentDateTime)}.',
    tz.TZDateTime.from(reminderTime, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'appointment_reminder_channel',
        'Appointment Reminders',
        channelDescription: 'Reminders for upcoming appointments',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dateAndTime,
  );
}
