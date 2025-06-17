import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sentimo/components/counselor/student_service.dart';

class CreateAppointmentComponent extends StatefulWidget {
  final VoidCallback? onCancel;
  final Function(Map<String, dynamic>)? onSubmit;

  const CreateAppointmentComponent({
    super.key,
    this.onCancel,
    this.onSubmit,
  });

  @override
  State<CreateAppointmentComponent> createState() => _CreateAppointmentComponentState();
}

class _CreateAppointmentComponentState extends State<CreateAppointmentComponent> {
  final _formKey = GlobalKey<FormState>();
  final StudentService _studentService = StudentService();
  
  // Form fields
  String? _selectedClientId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _sessionType = 'In-person';
  final TextEditingController _notesController = TextEditingController();
  
  // State variables
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final students = await _studentService.getStudents();
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load students: ${e.toString()}';
        _isLoading = false;
      });
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
      firstDate: DateTime.now(),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Appointment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? _buildErrorWidget()
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Student'),
                        _buildClientDropdown(),
                        const SizedBox(height: 24),
                        
                        _buildSectionTitle('Date & Time'),
                        _buildDateTimePicker(),
                        const SizedBox(height: 24),
                        
                        _buildSectionTitle('Session Type'),
                        _buildSessionTypeSelector(),
                        const SizedBox(height: 24),
                        
                        _buildSectionTitle('Notes (Optional)'),
                        _buildNotesField(),
                        const SizedBox(height: 32),
                        
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildErrorWidget() {
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
            onPressed: _loadStudents,
            child: const Text('Retry'),
          ),
        ],
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

  Widget _buildClientDropdown() {
    if (_students.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text('No students available. Please add students first.'),
          ),
        ),
      );
    }
    
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintText: 'Select a student',
      ),
      value: _selectedClientId,
      isExpanded: true,
      items: _students.map<DropdownMenuItem<String>>((student) {
        return DropdownMenuItem<String>(
          value: student['id'],
          child: Text(student['name']),
        );
      }).toList(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a student';
        }
        return null;
      },
      onChanged: (String? newValue) {
        setState(() {
          _selectedClientId = newValue;
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

  // Add the action buttons widget that matches the AppointmentFormComponent style
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

      // Find selected student's name for display
      final selectedStudent = _students.firstWhere(
        (student) => student['id'] == _selectedClientId,
        orElse: () => {'name': 'Unknown'},
      );

      final appointmentData = {
        'clientId': _selectedClientId,
        'clientName': selectedStudent['name'],
        'datetime': Timestamp.fromDate(appointmentDateTime),
        'sessionType': _sessionType, // Using the display format ('In-person' or 'Online')
        'status': 'upcoming',
        'notes': _notesController.text,
      };

      if (widget.onSubmit != null) {
        widget.onSubmit!(appointmentData);
      }
    }
  }
}
