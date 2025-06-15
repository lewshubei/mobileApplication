import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sentimo/components/counselor/appointment_service.dart';

class AppointmentListComponent extends StatefulWidget {
  final Function(Map<String, dynamic>)? onAppointmentTap;
  final Function(String)? onAppointmentDelete;

  const AppointmentListComponent({
    super.key,
    this.onAppointmentTap,
    this.onAppointmentDelete,
  });

  @override
  State<AppointmentListComponent> createState() => _AppointmentListComponentState();
}

class _AppointmentListComponentState extends State<AppointmentListComponent> with AutomaticKeepAliveClientMixin {
  // Changed from TabController to simple index tracking
  int _selectedIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final AppointmentService _appointmentService = AppointmentService();
  
  // State variables
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _appointments = [];
  DateTime _lastRefreshed = DateTime.now();
  
  // Get current user ID
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    // Initial data load
    _loadAppointments();
  }

  @override
  void didUpdateWidget(AppointmentListComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if enough time has passed since last refresh to avoid
    // refreshing too frequently (e.g., during rapid state changes)
    final now = DateTime.now();
    if (now.difference(_lastRefreshed).inSeconds >= 1) {
      _loadAppointments();
      _lastRefreshed = now;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Keep the tab alive even when switching between tabs
  @override
  bool get wantKeepAlive => true;
  
  // Get current status filter based on selected segment
  String _getCurrentStatusFilter() {
    switch (_selectedIndex) {
      case 0:
        return 'Upcoming';
      case 1:
        return 'Past';
      case 2:
        return 'Cancelled';
      default:
        return 'Upcoming';
    }
  }

  // Load appointments from Firestore
  Future<void> _loadAppointments() async {
    if (_currentUserId.isEmpty) {
      setState(() {
        _errorMessage = 'User not logged in';
        _isLoading = false;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final String statusFilter = _getCurrentStatusFilter();
      List<Map<String, dynamic>> appointments;
      
      if (_searchQuery.isEmpty) {
        appointments = await _appointmentService.getAppointmentsForCounselor(
          _currentUserId, 
          statusFilter
        );
      } else {
        appointments = await _appointmentService.searchAppointmentsByClientName(
          _currentUserId, 
          statusFilter,
          _searchQuery
        );
      }
      
      if (mounted) {
        setState(() {
          _appointments = appointments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load appointments: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // Method to handle appointment deletion
  void _handleDeleteAppointment(String appointmentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: const Text('Are you sure you want to delete this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (widget.onAppointmentDelete != null) {
                widget.onAppointmentDelete!(appointmentId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Column(
      children: [
        _buildSearchBar(),
        // Replaced TabBar with SegmentedControl
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: SegmentedControl(
              segments: const ['Upcoming', 'Past', 'Cancelled'],
              currentIndex: _selectedIndex,
              onSegmentTapped: (index) {
                setState(() {
                  _selectedIndex = index;
                });
                _loadAppointments(); // Reload appointments when segment changes
              },
              primaryColor: Theme.of(context).primaryColor,
            ),
          ),
        ),
        Expanded(
          child: _buildAppointmentList(_getCurrentStatusFilter()),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          _loadAppointments(); // Reload appointments with search query
        },
        decoration: InputDecoration(
          hintText: 'Search by client name',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                    _loadAppointments(); // Reload without search query
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildAppointmentList(String status) {
    // Show loading indicator
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    // Show error message if any
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAppointments,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    // Show no appointments message if list is empty
    if (_appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'Upcoming' ? Icons.event_available : Icons.event_busy,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No $status appointments found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Try adjusting your search',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      );
    }
    
    // Show appointments list
    return ListView.builder(
      itemCount: _appointments.length,
      padding: const EdgeInsets.only(bottom: 16),
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    Color statusColor;
    IconData statusIcon;

    switch (appointment['status']) {
      case 'Upcoming':
        statusColor = Colors.green;
        statusIcon = Icons.schedule;
        break;
      case 'Past':
        statusColor = Colors.blue;
        statusIcon = Icons.done_all;
        break;
      case 'Cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (widget.onAppointmentTap != null) {
            widget.onAppointmentTap!(appointment);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    child: Text(
                      appointment['clientName'] != null && appointment['clientName'].isNotEmpty 
                          ? appointment['clientName'][0]
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment['clientName'] ?? 'Unknown Client',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appointment['dateTime'] != null
                              ? DateFormat('EEEE, MMMM d, yyyy • h:mm a')
                                  .format(appointment['dateTime'])
                              : 'No date available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                          appointment['status'],
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (appointment['notes'] != null && appointment['notes'].isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Notes:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appointment['notes'],
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Removed Edit and Cancel buttons for Upcoming appointments
                  if (appointment['status'] == 'Past') ...[
                    _buildActionButton(
                      icon: Icons.note_add,
                      label: 'Add Notes',
                      onTap: () {
                        if (widget.onAppointmentTap != null) {
                          widget.onAppointmentTap!(appointment);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    // Add delete button for completed appointments
                    _buildActionButton(
                      icon: Icons.delete,
                      label: 'Delete',
                      isDestructive: true,
                      onTap: () {
                        _handleDeleteAppointment(appointment['id']);
                      },
                    ),
                  ] else if (appointment['status'] == 'Cancelled') ...[
                    _buildActionButton(
                      icon: Icons.restore,
                      label: 'Reschedule',
                      onTap: () {
                        if (widget.onAppointmentTap != null) {
                          widget.onAppointmentTap!(appointment);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    // Add delete button for cancelled appointments
                    _buildActionButton(
                      icon: Icons.delete,
                      label: 'Delete',
                      isDestructive: true,
                      onTap: () {
                        _handleDeleteAppointment(appointment['id']);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom SegmentedControl widget for Flutter
class SegmentedControl extends StatelessWidget {
  final List<String> segments;
  final int currentIndex;
  final Function(int) onSegmentTapped;
  final Color primaryColor;

  const SegmentedControl({
    super.key,
    required this.segments,
    required this.currentIndex,
    required this.onSegmentTapped,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(segments.length, (index) {
        final isSelected = currentIndex == index;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSegmentTapped(index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                segments[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
