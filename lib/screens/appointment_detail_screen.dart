import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    // Create a deep copy of the appointment data to avoid modifying the original directly
    _currentAppointment = Map<String, dynamic>.from(widget.appointment);
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _updateAppointment(Map<String, dynamic> updatedData) {
    setState(() {
      _currentAppointment = updatedData;
      _isEditing = false;
    });
    
    // Call the callback to notify parent about the update
    if (widget.onUpdate != null) {
      widget.onUpdate!(_currentAppointment);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appointment updated successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Appointment' : 'Appointment Details'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEditMode,
              tooltip: 'Edit Appointment',
            ),
        ],
      ),
      body: _isEditing
          ? AppointmentFormComponent(
              initialData: _currentAppointment,
              onCancel: _toggleEditMode,
              onSubmit: _updateAppointment,
            )
          : _buildAppointmentDetails(),
    );
  }

  Widget _buildAppointmentDetails() {
    final Color statusColor = _getStatusColor(_currentAppointment['status']);
    final IconData statusIcon = _getStatusIcon(_currentAppointment['status']);
    final theme = Theme.of(context);
    
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
                      _currentAppointment['clientName'][0],
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
                          _currentAppointment['clientName'],
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
                                    _currentAppointment['status'],
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
                              _currentAppointment['sessionType'],
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
                  .format(_currentAppointment['dateTime']),
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
              _currentAppointment['sessionType'],
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
          if (_currentAppointment['status'] == 'Upcoming') ...[
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
          ] else if (_currentAppointment['status'] == 'Past') ...[
            _buildActionButton(
              icon: Icons.note_add,
              label: 'Add Session Notes',
              onTap: _toggleEditMode,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.delete_outline,
              label: 'Delete Appointment',
              isDestructive: true,
              onTap: () {
                _showDeleteConfirmationDialog();
              },
            ),
          ] else if (_currentAppointment['status'] == 'Cancelled') ...[
            _buildActionButton(
              icon: Icons.restore,
              label: 'Reschedule Appointment',
              onTap: _toggleEditMode,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.delete_outline,
              label: 'Delete Appointment',
              isDestructive: true,
              onTap: () {
                _showDeleteConfirmationDialog();
              },
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
              // Update appointment status to 'Cancelled' and handle the change
              Map<String, dynamic> cancelledAppointment = Map<String, dynamic>.from(_currentAppointment);
              cancelledAppointment['status'] = 'Cancelled';
              _updateAppointment(cancelledAppointment);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel Appointment'),
          ),
        ],
      ),
    );
  }

  // New method for delete confirmation dialog
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: const Text(
          'Are you sure you want to delete this appointment?',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Here you would add code to delete the appointment
              // For now, just show a success message and navigate back
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to previous screen
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appointment deleted successfully')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Upcoming':
        return Colors.green;
      case 'Past':
        return Colors.blue;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Upcoming':
        return Icons.schedule;
      case 'Past':
        return Icons.done_all;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
}
