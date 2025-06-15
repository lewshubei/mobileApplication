import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sentimo/components/counselor/appointment_form_component.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final Function(Map<String, dynamic>)? onUpdate;

  const AppointmentDetailScreen({
    super.key,
    required this.appointment,
    this.onUpdate,
  });

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late Map<String, dynamic> _currentAppointment;
  bool _isEditing = false;
  bool _isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Initialize with passed data, but will be updated from Firestore
    _currentAppointment = Map<String, dynamic>.from(widget.appointment);
    // Fetch complete appointment data from Firestore
    _fetchAppointmentDetails();
  }

  // Fetch complete appointment data from Firestore using the document ID
  Future<void> _fetchAppointmentDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String? appointmentId = _currentAppointment['id'];
      if (appointmentId == null) {
        throw Exception('Appointment ID is missing');
      }

      final DocumentSnapshot appointmentDoc = 
          await _firestore.collection('appointments').doc(appointmentId).get();
          
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }

      final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      
      // Add the ID to the data for later use
      appointmentData['id'] = appointmentDoc.id;
      
      setState(() {
        _currentAppointment = appointmentData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching appointment details: ${e.toString()}')),
        );
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  // Update the appointment in Firestore
  Future<void> _updateAppointment(Map<String, dynamic> updatedData) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get the appointment ID
      final appointmentId = _currentAppointment['id'];
      if (appointmentId == null) {
        throw Exception('Appointment ID is missing');
      }
      
      // Create update fields map
      final Map<String, dynamic> updateFields = {};
      
      // Handle datetime update
      if (updatedData['datetime'] != null) {
        // Convert DateTime to Firestore Timestamp
        updateFields['datetime'] = Timestamp.fromDate(updatedData['datetime'] as DateTime);
      }
      
      // Handle other fields
      if (updatedData['notes'] != null) {
        updateFields['notes'] = updatedData['notes'];
      }
      
      if (updatedData['sessionType'] != null) {
        updateFields['sessionType'] = updatedData['sessionType'];
      }
      
      if (updatedData['status'] != null) {
        updateFields['status'] = updatedData['status'];
      }
      
      // Only proceed if we have fields to update
      if (updateFields.isNotEmpty) {
        // Update in Firestore
        await _firestore
            .collection('appointments')
            .doc(appointmentId)
            .update(updateFields);
        
        // Update the current appointment state with the new data
        setState(() {
          // Update each field individually to preserve other data
          updateFields.forEach((key, value) {
            _currentAppointment[key] = value;
          });
          
          _isLoading = false;
          _isEditing = false;
        });
        
        // Call the callback to notify parent about the update
        if (widget.onUpdate != null) {
          widget.onUpdate!(_currentAppointment);
        }
        
        // Removed the SnackBar here to fix duplicate notification issue
        // The parent component (CounselorHomeScreen) will show the notification
      } else {
        setState(() {
          _isLoading = false;
          _isEditing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes to update')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update appointment: ${e.toString()}')),
        );
      }
    }
  }

  // Convert Firestore timestamp to DateTime for editing
  DateTime _getAppointmentDateTime() {
    if (_currentAppointment['datetime'] is Timestamp) {
      return (_currentAppointment['datetime'] as Timestamp).toDate();
    }
    return DateTime.now(); // Fallback
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Appointment' : 'Appointment Details'),
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEditMode,
              tooltip: 'Edit Appointment',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isEditing
              ? AppointmentFormComponent(
                  initialData: {
                    'id': _currentAppointment['id'],
                    'clientId': _currentAppointment['clientId'],
                    'clientName': _currentAppointment['clientName'] ?? 'Client',
                    'datetime': _getAppointmentDateTime(),
                    'sessionType': _currentAppointment['sessionType'] ?? 'In-person',
                    'status': _currentAppointment['status'] ?? 'upcoming',
                    'notes': _currentAppointment['notes'] ?? '',
                  },
                  onCancel: _toggleEditMode,
                  onSubmit: _updateAppointment,
                )
              : _buildAppointmentDetails(),
    );
  }

  Widget _buildAppointmentDetails() {
    final Color statusColor = _getStatusColor(_currentAppointment['status'] ?? '');
    final IconData statusIcon = _getStatusIcon(_currentAppointment['status'] ?? '');
    final theme = Theme.of(context);
    final DateTime appointmentDateTime = _getAppointmentDateTime();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client Information Card
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    radius: 30,
                    child: Text(
                      (_currentAppointment['clientName'] ?? 'Client')[0],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentAppointment['clientName'] ?? 'Client',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 16, color: statusColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    _currentAppointment['status'] ?? 'Unknown',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentAppointment['sessionType'] == 'In-person'
                                  ? Icons.person
                                  : Icons.video_call,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentAppointment['sessionType'] ?? 'Unknown',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
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
          ),

          // Date & Time Section
          _buildDetailSection(
            title: 'Date & Time',
            icon: Icons.calendar_today,
            child: Text(
              DateFormat('EEEE, MMMM d, yyyy • h:mm a')
                  .format(appointmentDateTime),
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),

          // Session Type Section
          _buildDetailSection(
            title: 'Session Type',
            icon: _currentAppointment['sessionType'] == 'In-person'
                ? Icons.person
                : Icons.video_call,
            child: Text(
              _currentAppointment['sessionType'] ?? 'Unknown',
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),

          // Notes Section
          _buildDetailSection(
            title: 'Notes',
            icon: Icons.note,
            child: _currentAppointment['notes'] != null &&
                    _currentAppointment['notes'].isNotEmpty
                ? Text(
                    _currentAppointment['notes'],
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  )
                : Text(
                    'No notes available',
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
          ),

          // Action Buttons
          const SizedBox(height: 24),
          if (_currentAppointment['status'] == 'upcoming') ...[
            _buildActionButton(
              icon: Icons.edit,
              label: 'Edit Appointment',
              onTap: _toggleEditMode,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.cancel_outlined,
              label: 'Cancel Appointment',
              isDestructive: true,
              onTap: () {
                // Show confirmation dialog and handle cancellation
                _showCancelConfirmationDialog();
              },
            ),
          ] else if (_currentAppointment['status'] == 'completed') ...[
            _buildActionButton(
              icon: Icons.note_add,
              label: 'Add Session Notes',
              onTap: _toggleEditMode,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : Theme.of(context).primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
          color: isDestructive ? Colors.red.withOpacity(0.1) : color.withOpacity(0.1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text(
          'Are you sure you want to cancel this appointment? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep Appointment'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Only update the status field, not the entire appointment object
              _updateAppointment({'status': 'cancelled'});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel Appointment'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
        return Icons.schedule;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
}
