import 'package:flutter/material.dart';
import 'dashboard.dart';

class BookingDateTimeView extends StatefulWidget {
  final String serviceName;
  final String? servicePrice;

  const BookingDateTimeView({
    super.key,
    required this.serviceName,
    this.servicePrice,
  });

  @override
  State<BookingDateTimeView> createState() => _BookingDateTimeViewState();
}

class _BookingDateTimeViewState extends State<BookingDateTimeView> {
  final Map<String, Map<String, String>> _serviceDoctors = {
    'Braces': {
      'name': 'Dr. Sarah Smith',
      'role': 'Orthodontist',
      'image': 'images/sarah.png'
    },
    'Scaling': {
      'name': 'Dr. John Doe',
      'role': 'Surgeon',
      'image': 'images/john.png'
    },
    'Whitening': {
      'name': 'Dr. Sarah Smith',
      'role': 'Aesthetic Dentist',
      'image': 'images/sarah.png'
    },
    'Retainers': {
      'name': 'Dr. John Doe',
      'role': 'General Dentist',
      'image': 'images/john.png'
    },
  };

  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  
  final List<String> _timeSlots = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', 
    '11:00 AM', '02:00 PM', '02:30 PM', '03:00 PM', '04:00 PM'
  ];

  Map<String, String> _getDoctorInfo() {
    String key = 'Scaling'; 
    if (widget.serviceName.contains('Braces') || widget.serviceName.contains('Metal') || widget.serviceName.contains('Ceramic')) {
      key = 'Braces';
    } else if (widget.serviceName.contains('Whitening')) {
      key = 'Whitening';
    } else if (widget.serviceName.contains('Retainer')) {
      key = 'Retainers';
    }
    return _serviceDoctors[key] ?? _serviceDoctors['Scaling']!;
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = _getDoctorInfo();
    final Color primaryYellow = const Color(0xFFFBC02D);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _handleBack,
        ),
        title: const Text(
          'Select Date & Time',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Consulting Doctor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: primaryYellow.withValues(alpha: 0.2),
                          backgroundImage: AssetImage(doctor['image']!),
                          onBackgroundImageError: (_,_) {},
                          child: const Icon(Icons.person),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctor['name']!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                doctor['role']!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, color: Color(0xFFFBC02D), size: 28),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'Select Date',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDE7), 
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: CalendarDatePicker(
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                      onDateChanged: (date) {
                        setState(() {
                          _selectedDate = date;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'Available Time',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: _timeSlots.map((time) {
                      bool isSelected = _selectedTime == time;
                      return ChoiceChip(
                        label: Text(time),
                        selected: isSelected,
                        selectedColor: primaryYellow,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : Colors.grey.shade300,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedTime = selected ? time : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _selectedTime != null
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Booking Confirmed!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        // Pop until Dashboard
                        Navigator.popUntil(context, (route) => route.isFirst);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryYellow,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  disabledBackgroundColor: Colors.grey[200],
                ),
                child: const Text(
                  'Confirm Booking',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}