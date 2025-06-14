import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppointmentListComponent extends StatefulWidget {
  const AppointmentListComponent({super.key});

  @override
  State<AppointmentListComponent> createState() => _AppointmentListComponentState();
}

class _AppointmentListComponentState extends State<AppointmentListComponent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'Cancelled'),
          ],
          labelColor: Theme.of(context).primaryColor,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAppointmentList('Upcoming'),
              _buildAppointmentList('Past'),
              _buildAppointmentList('Cancelled'),
            ],
          ),
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
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildAppointmentList(String status) {
    // This would be replaced by actual data from your database
    // For now, we're using mock data
    final List<Map<String, dynamic>> mockAppointments = _getMockAppointments(status);
    
    // Filter appointments based on search query
    final filteredAppointments = _searchQuery.isEmpty
        ? mockAppointments
        : mockAppointments.where(
            (appointment) => appointment['clientName']
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()),
          ).toList();

    if (filteredAppointments.isEmpty) {
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

    return ListView.builder(
      itemCount: filteredAppointments.length,
      padding: const EdgeInsets.only(bottom: 16),
      itemBuilder: (context, index) {
        final appointment = filteredAppointments[index];
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
          // Will be implemented in future for appointment details
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
                      appointment['clientName'][0],
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
                          appointment['clientName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy • h:mm a')
                              .format(appointment['dateTime']),
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
                  if (appointment['status'] == 'Upcoming') ...[
                    _buildActionButton(
                      icon: Icons.edit,
                      label: 'Edit',
                      onTap: () {
                        // Will be implemented in future
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.cancel_outlined,
                      label: 'Cancel',
                      isDestructive: true,
                      onTap: () {
                        // Will be implemented in future
                      },
                    ),
                  ] else if (appointment['status'] == 'Past') ...[
                    _buildActionButton(
                      icon: Icons.note_add,
                      label: 'Add Notes',
                      onTap: () {
                        // Will be implemented in future
                      },
                    ),
                  ] else if (appointment['status'] == 'Cancelled') ...[
                    _buildActionButton(
                      icon: Icons.restore,
                      label: 'Reschedule',
                      onTap: () {
                        // Will be implemented in future
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

  List<Map<String, dynamic>> _getMockAppointments(String status) {
    final now = DateTime.now();

    switch (status) {
      case 'Upcoming':
        return [
          {
            'id': '1',
            'clientName': 'Alex Johnson',
            'dateTime': now.add(const Duration(days: 1)),
            'status': 'Upcoming',
            'notes': 'Follow-up session on anxiety management techniques'
          },
          {
            'id': '2',
            'clientName': 'Sarah Williams',
            'dateTime': now.add(const Duration(days: 2, hours: 3)),
            'status': 'Upcoming',
            'notes': 'Initial assessment'
          },
          {
            'id': '3',
            'clientName': 'Mike Chen',
            'dateTime': now.add(const Duration(days: 3, hours: 1)),
            'status': 'Upcoming',
            'notes': ''
          },
        ];
      case 'Past':
        return [
          {
            'id': '4',
            'clientName': 'Emily Rogers',
            'dateTime': now.subtract(const Duration(days: 2)),
            'status': 'Past',
            'notes': 'Completed initial assessment. Scheduled follow-up in 2 weeks.'
          },
          {
            'id': '5',
            'clientName': 'James Wilson',
            'dateTime': now.subtract(const Duration(days: 5)),
            'status': 'Past',
            'notes': 'Discussed coping mechanisms for stress'
          },
        ];
      case 'Cancelled':
        return [
          {
            'id': '6',
            'clientName': 'Lisa Thompson',
            'dateTime': now.subtract(const Duration(days: 1)),
            'status': 'Cancelled',
            'notes': 'Student had a scheduling conflict'
          },
        ];
      default:
        return [];
    }
  }
}
