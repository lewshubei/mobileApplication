import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:sentimo/services/notification_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _loading = true;
  List<_UnifiedNotification> _allNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadAllNotifications();
  }

  Future<void> _loadAllNotifications() async {
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _allNotifications = [];
        _loading = false;
      });
      return;
    }
    // 1. Load local motivational quotes
    final localQuotes = await NotificationService().getNotifications();

    // Filter: Only one quote per day (keep the latest for each day)
    final Map<String, _UnifiedNotification> quoteByDay = {};
    for (final q in localQuotes) {
      final dayKey = DateFormat('yyyy-MM-dd').format(q.dateTime);
      final notif = _UnifiedNotification(
        message: q.quote,
        dateTime: q.dateTime,
        type: _NotifType.quote,
      );
      // If there's already a quote for this day, keep the latest one
      if (!quoteByDay.containsKey(dayKey) || q.dateTime.isAfter(quoteByDay[dayKey]!.dateTime)) {
        quoteByDay[dayKey] = notif;
      }
    }
    final localUnified = quoteByDay.values.toList();

    // 2. Load Firestore appointments
    final firestoreSnapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('studentId', isEqualTo: user.uid)
        .orderBy('datetime', descending: true)
        .get();
    final firestoreUnified = firestoreSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final counselorName = data['counselorName'] ?? 'Counselor';
      final dateTime = data['datetime'] != null
          ? (data['datetime'] as Timestamp).toDate()
          : DateTime.now();
      final status = data['status'] ?? 'upcoming';
      
      String message;
      switch (status) {
        case 'cancelled':
          message = "Your appointment with $counselorName on "
              "${DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime)} has been cancelled.";
          break;
        case 'completed':
          message = "Your appointment with $counselorName on "
              "${DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime)} has been completed.";
          break;
        default:
          message = "You have an appointment with $counselorName on "
              "${DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime)}.";
      }
      
      return _UnifiedNotification(
        message: message,
        dateTime: dateTime,
        type: _NotifType.appointment,
        status: status,
      );
    }).toList();

    // 3. Merge and sort
    final allNotifs = [...localUnified, ...firestoreUnified];
    allNotifs.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    setState(() {
      _allNotifications = allNotifs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color.fromARGB(255, 241, 245, 229),
        foregroundColor: const Color.fromARGB(255, 36, 99, 12),
        elevation: 0.5,
      ),
      backgroundColor: const Color.fromARGB(255, 241, 245, 229),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allNotifications.isEmpty
              ? _buildEmptyState(theme)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allNotifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notif = _allNotifications[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: notif.type == _NotifType.quote
                                    ? const Color.fromARGB(255, 211, 231, 190)
                                    : const Color.fromARGB(255, 255, 243, 207),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                notif.type == _NotifType.quote
                                    ? Icons.format_quote
                                    : (notif.status == 'cancelled' 
                                        ? Icons.cancel 
                                        : Icons.event),
                                color: notif.type == _NotifType.quote
                                    ? const Color.fromARGB(255, 31, 153, 27)
                                    : (notif.status == 'cancelled' 
                                        ? Colors.red 
                                        : Colors.orange.shade700),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notif.message,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color.fromARGB(255, 36, 99, 12),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('MMM dd, yyyy – hh:mm a').format(notif.dateTime),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 64,
              color: Colors.purple.shade100,
            ),
            const SizedBox(height: 24),
            Text(
              'No notifications yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.purple.shade900,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'You will receive motivational quotes and appointment notifications here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.purple.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum _NotifType { quote, appointment }

class _UnifiedNotification {
  final String message;
  final DateTime dateTime;
  final _NotifType type;
  final String? status;
  _UnifiedNotification({
    required this.message, 
    required this.dateTime, 
    required this.type,
    this.status,
  });
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
    'type': 'appointment', // Optional: to distinguish notification type
  });
}

Future<void> sendAppointmentCancellationNotification({
  required String studentId,
  required String counselorName,
  required DateTime appointmentDateTime,
}) async {
  final message = "Your appointment with Counselor $counselorName on "
      "${DateFormat('MMM dd, yyyy – hh:mm a').format(appointmentDateTime)} has been cancelled.";

  await FirebaseFirestore.instance.collection('notifications').add({
    'userId': studentId,
    'message': message,
    'timestamp': FieldValue.serverTimestamp(),
    'seen': false,
    'type': 'cancellation', // Optional: to distinguish notification type
  });
}
