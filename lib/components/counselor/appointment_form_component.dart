import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  String? _selectedClient;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _sessionType;
  late String _status;
  final TextEditingController _notesController = TextEditingController();

  // Mock client list - replace with actual data source
  final List<String> _mockClients = [
    'Alex Johnson',
    'Sarah Williams',
    'Mike Chen',
    'Emily Rogers',
    'James Wilson',
    'Lisa Thompson',
  ];

  @override
  void initState() {
    super.initState();
    
    if (widget.initialData != null) {
      // Initialize form with existing data
      _selectedClient = widget.initialData!['clientName'];
      
      final dateTime = widget.initialData!['dateTime'] as DateTime;
      _selectedDate = dateTime;
      _selectedTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
      
      _sessionType = widget.initialData!['sessionType'] ?? 'In-person';
      _status = widget.initialData!['status'] ?? 'Upcoming';
      _notesController.text = widget.initialData!['notes'] ?? '';
    } else {
      // Initialize with default values for new appointment
      _selectedDate = DateTime.now().add(const Duration(days: 1));
      _selectedTime = TimeOfDay.now();
      _sessionType = 'In-person';
      _status = 'Upcoming';
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
        _selectedDate = picked;
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
              _buildSectionTitle('Client'),
              _buildClientField(),
              const SizedBox(height: 24),
              
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
    // If editing existing appointment, client name is read-only
    if (widget.initialData != null) {
      return InputDecorator(
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        child: Text(_selectedClient ?? 'No client selected'),
      );
    }
    
    // For new appointments, show dropdown
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintText: 'Select a client',
      ),
      value: _selectedClient,
      isExpanded: true,
      items: _mockClients.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a client';
        }
        return null;
      },
      onChanged: (String? newValue) {
        setState(() {
          _selectedClient = newValue;
        });
      },
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
    // Use segmented button for status selection
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment<String>(
          value: 'Upcoming',
          label: Text('Upcoming'),
          icon: Icon(Icons.schedule),
        ),
        ButtonSegment<String>(
          value: 'Completed',
          label: Text('Completed'),
          icon: Icon(Icons.done_all),
        ),
        ButtonSegment<String>(
          value: 'Cancelled',
          label: Text('Cancelled'),
          icon: Icon(Icons.cancel),
        ),
      ],
      selected: {_status},
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
      // Combine date and time into a single DateTime
      final appointmentDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final appointmentData = {
        'clientName': _selectedClient,
        'dateTime': appointmentDateTime,
        'sessionType': _sessionType,
        'status': _status,
        'notes': _notesController.text,
      };

      if (widget.onSubmit != null) {
        widget.onSubmit!(appointmentData);
      }
    }
  }
}
