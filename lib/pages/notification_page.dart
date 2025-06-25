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
    _markNotificationsAsSeen();
  }

  Future<void> _markNotificationsAsSeen() async {
    await NotificationService().markAllAsSeen();
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

    // 1. Load local notifications (quotes + bad mood alerts)
    final localNotifications = await NotificationService().getNotifications();

    // Group quotes by day and keep assessment notifications separate
    final Map<String, _UnifiedNotification> quoteByDay = {};
    final List<_UnifiedNotification> assessmentNotifications = [];

    for (final notif in localNotifications) {
      if (notif.type == 'bad_mood_streak') {
        assessmentNotifications.add(_UnifiedNotification(
          message: notif.quote,
          dateTime: notif.dateTime,
          type: _NotifType.assessment,
        ));
      } else {
        final dayKey = DateFormat('yyyy-MM-dd').format(notif.dateTime);
        final unifiedNotif = _UnifiedNotification(
          message: notif.quote,
          dateTime: notif.dateTime,
          type: _NotifType.quote,
        );
        
        if (!quoteByDay.containsKey(dayKey) || 
            notif.dateTime.isAfter(quoteByDay[dayKey]!.dateTime)) {
          quoteByDay[dayKey] = unifiedNotif;
        }
      }
    }

    final localUnified = [...quoteByDay.values, ...assessmentNotifications];

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
      final sessionType = data['sessionType'] ?? 'In-person';
      final status = data['status'] ?? 'upcoming';
      final notes = data['notes'] ?? '';
      
      String message;
      switch (status) {
        case 'cancelled':
          message = "Your $sessionType appointment with $counselorName on "
              "${DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime)} has been cancelled.";
          break;
        case 'completed':
          message = "Your $sessionType appointment with $counselorName on "
              "${DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime)} has been completed.";
          break;
        default:
          message = "You have a $sessionType appointment with $counselorName on "
              "${DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime)}.";
          if (sessionType.toLowerCase() == 'online' && notes.isNotEmpty) {
            message += " Meeting link: $notes";
          }
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
                    return _buildNotificationCard(notif, theme);
                  },
                ),
    );
  }

  Widget _buildNotificationCard(_UnifiedNotification notif, ThemeData theme) {
    IconData iconData;
    Color iconColor;
    Color backgroundColor;
    
    switch (notif.type) {
      case _NotifType.quote:
        iconData = Icons.format_quote;
        iconColor = const Color.fromARGB(255, 31, 153, 27);
        backgroundColor = const Color.fromARGB(255, 211, 231, 190);
        break;
      case _NotifType.assessment:
        iconData = Icons.psychology;
        iconColor = Colors.purple.shade700;
        backgroundColor = Colors.purple.shade100;
        break;
      case _NotifType.appointment:
        iconData = notif.status == 'cancelled' ? Icons.cancel : Icons.event;
        iconColor = notif.status == 'cancelled' ? Colors.red : Colors.orange.shade700;
        backgroundColor = const Color.fromARGB(255, 255, 243, 207);
        break;
    }

    return Card(
      elevation: notif.type == _NotifType.assessment ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: notif.type == _NotifType.assessment 
            ? BorderSide(color: Colors.purple.shade300, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: notif.type == _NotifType.assessment 
            ? () => _onAssessmentNotificationTap() 
            : null,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconData,
                  color: iconColor,
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
                    if (notif.type == _NotifType.assessment) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app, size: 16, color: Colors.purple.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to take assessment',
                              style: TextStyle(
                                color: Colors.purple.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onAssessmentNotificationTap() {
    // Show confirmation dialog first
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.psychology, color: Colors.purple.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mental Health Assessment',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: const Text(
            'We noticed you\'ve been feeling down lately. Taking a mental health assessment can help you understand your wellbeing and get appropriate support.\n\nWould you like to take the assessment now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _navigateToAssessment();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Take Assessment'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToAssessment() {
    // Navigate back to home screen with assessment tab selected
    Navigator.of(context).pop({'navigateToTab': 3});
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
              'You will receive motivational quotes, mental health check-ins, and appointment notifications here.',
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

enum _NotifType { quote, appointment, assessment }

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
    'type': 'appointment',
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
    'type': 'cancellation',
  });
}
