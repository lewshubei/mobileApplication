import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentFormComponent extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback? onCancel;
  final Function(Map<String, dynamic>)? onSubmit;

  const AppointmentFormComponent({
    super.key,
    this.initialData,
    this.onCancel,
    this.onSubmit,
  });

  @override
  State<AppointmentFormComponent> createState() => _AppointmentFormComponentState();
}

class _AppointmentFormComponentState extends State<AppointmentFormComponent> {
  final _formKey = GlobalKey<FormState>();
  
  // Form fields
  String? _clientId;
  String? _selectedClientName;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _sessionType;
  late String _status;
  final TextEditingController _notesController = TextEditingController();
  String? _appointmentId;
  
  // Track if date or time was changed
  bool _dateChanged = false;
  bool _timeChanged = false;
  late DateTime _originalDateTime;

  @override
  void initState() {
    super.initState();
    
    if (widget.initialData != null) {
      // Initialize form with existing data
      _appointmentId = widget.initialData!['id'];
      _clientId = widget.initialData!['clientId'];
      _selectedClientName = widget.initialData!['clientName'];
      
      // Handle date/time from Firestore Timestamp or DateTime
      DateTime dateTime;
      if (widget.initialData!['datetime'] is Timestamp) {
        dateTime = (widget.initialData!['datetime'] as Timestamp).toDate();
      } else if (widget.initialData!['datetime'] is DateTime) {
        dateTime = widget.initialData!['datetime'] as DateTime;
      } else {
        dateTime = DateTime.now();
      }
      
      _selectedDate = dateTime;
      _selectedTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
      _originalDateTime = dateTime;
      
      _sessionType = widget.initialData!['sessionType'] ?? 'In-person';
      _status = widget.initialData!['status'] ?? 'upcoming';
      _notesController.text = widget.initialData!['notes'] ?? '';
    } else {
      // Initialize with default values for new appointment
      _selectedDate = DateTime.now().add(const Duration(days: 1));
      _selectedTime = TimeOfDay.now();
      _originalDateTime = _selectedDate;
      _sessionType = 'In-person';
      _status = 'upcoming';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // Allow past dates for editing existing appointments
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
        _dateChanged = true;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _timeChanged = true;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    final dateTime = DateTime(
      now.year, 
      now.month, 
      now.day, 
      timeOfDay.hour, 
      timeOfDay.minute
    );
    return DateFormat('h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.initialData != null) ...[
                _buildSectionTitle('Student'),
                _buildClientField(),
                const SizedBox(height: 24),
              ],
              
              _buildSectionTitle('Date & Time'),
              _buildDateTimePicker(),
              const SizedBox(height: 24),
              
              _buildSectionTitle('Session Type'),
              _buildSessionTypeSelector(),
              const SizedBox(height: 24),
              
              _buildSectionTitle('Status'),
              _buildStatusSelector(),
              const SizedBox(height: 24),
              
              _buildSectionTitle('Notes'),
              _buildNotesField(),
              const SizedBox(height: 32),
              
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildClientField() {
    return InputDecorator(
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      child: Text(_selectedClientName ?? 'No client selected'),
    );
  }

  Widget _buildDateTimePicker() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: () => _selectDate(context),
            child: InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: const Icon(Icons.calendar_month),
              ),
              child: Text(
                DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: () => _selectTime(context),
            child: InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: const Icon(Icons.access_time),
              ),
              child: Text(_formatTimeOfDay(_selectedTime)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildSessionTypeOption('In-person', Icons.person),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSessionTypeOption('Online', Icons.video_call),
        ),
      ],
    );
  }

  Widget _buildSessionTypeOption(String type, IconData icon) {
    final isSelected = _sessionType == type;
    
    return InkWell(
      onTap: () {
        setState(() {
          _sessionType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: isSelected 
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: isSelected 
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              type,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected 
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment<String>(
          value: 'upcoming',
          label: Text('Upcoming'),
          icon: Icon(Icons.schedule),
        ),
        ButtonSegment<String>(
          value: 'completed',
          label: Text('Completed'),
          icon: Icon(Icons.done_all),
        ),
        ButtonSegment<String>(
          value: 'cancelled',
          label: Text('Cancelled'),
          icon: Icon(Icons.cancel),
        ),
      ],
      selected: {_status.toLowerCase()},
      onSelectionChanged: (Set<String> selected) {
        setState(() {
          _status = selected.first;
        });
      },
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return Theme.of(context).primaryColor;
            }
            return Colors.transparent;
          },
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 4,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        hintText: 'Add any notes about this appointment...',
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('CANCEL'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('SAVE'),
          ),
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Create a complete DateTime that combines the selected date and time
      final DateTime appointmentDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final Map<String, dynamic> appointmentData = {
        'id': _appointmentId, // Keep the ID for reference
        'clientId': _clientId, // Keep the clientId
        'sessionType': _sessionType,
        'status': _status,
        'notes': _notesController.text,
        
        // Include client name just for UI display purposes
        'clientName': _selectedClientName,
      };
      
      // Only include datetime if it was changed
      if (_dateChanged || _timeChanged) {
        appointmentData['datetime'] = appointmentDateTime;
      }

      if (widget.onSubmit != null) {
        widget.onSubmit!(appointmentData);
      }
    }
  }
}
