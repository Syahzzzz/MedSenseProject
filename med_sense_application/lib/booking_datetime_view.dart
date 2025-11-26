import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'translations.dart';
import 'review_confirm_view.dart';

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
  // --- Clinic Data ---
  final List<Map<String, dynamic>> _clinics = [
    {
      'nameKey': 'dental_clinic_rawang',
      'address': 'Reef 2, Rawang',
      'image': 'images/clinic_rawang.png',
      'id': 'rawang',
    },
    {
      'nameKey': 'dental_clinic_selayang',
      'address': 'Emerald Avenue, Selayang',
      'image': 'images/clinic_selayang.png',
      'id': 'selayang',
    },
    {
      'nameKey': 'dental_clinic_kl',
      'address': 'Nu Sentral, KL',
      'image': 'images/clinic_kl.png',
      'id': 'kl',
    },
  ];

  // --- Dynamic Doctor Database (Mapped by Clinic ID + Service Type) ---
  final Map<String, Map<String, Map<String, String>>> _doctorDatabase = {
    'rawang': {
      'Braces': {'name': 'Dr. Sarah Smith', 'role': 'Orthodontist'},
      'Scaling': {'name': 'Dr. John Doe', 'role': 'Senior Surgeon'},
      'Whitening': {'name': 'Dr. Sarah Smith', 'role': 'Aesthetic Dentist'},
      'Retainers': {'name': 'Dr. John Doe', 'role': 'General Dentist'},
    },
    'selayang': {
      'Braces': {'name': 'Dr. Emily Wong', 'role': 'Orthodontist'},
      'Scaling': {'name': 'Dr. Michael Tan', 'role': 'Dental Surgeon'},
      'Whitening': {'name': 'Dr. Emily Wong', 'role': 'Aesthetic Specialist'},
      'Retainers': {'name': 'Dr. Michael Tan', 'role': 'General Dentist'},
    },
    'kl': {
      'Braces': {'name': 'Dr. David Lee', 'role': 'Senior Orthodontist'},
      'Scaling': {'name': 'Dr. Jessica Lim', 'role': 'Oral Surgeon'},
      'Whitening': {'name': 'Dr. Jessica Lim', 'role': 'Cosmetic Dentist'},
      'Retainers': {'name': 'Dr. David Lee', 'role': 'General Dentist'},
    },
  };

  // --- State ---
  int _selectedClinicIndex = 0; // Default to first clinic
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  
  final List<String> _timeSlots = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', 
    '11:00 AM', '02:00 PM', '02:30 PM', '03:00 PM', '04:00 PM'
  ];

  // Helper to determine the service category key
  String _getServiceKey() {
    if (widget.serviceName.contains('Braces') || widget.serviceName.contains('Metal') || widget.serviceName.contains('Ceramic')) {
      return 'Braces';
    } else if (widget.serviceName.contains('Whitening')) {
      return 'Whitening';
    } else if (widget.serviceName.contains('Retainer')) {
      return 'Retainers';
    }
    return 'Scaling'; // Default
  }

  // Get the correct doctor based on current Clinic AND Service
  Map<String, String> _getDoctorInfo() {
    final String serviceKey = _getServiceKey();
    final String clinicId = _clinics[_selectedClinicIndex]['id'];
    
    // Fetch doctor or fallback
    return _doctorDatabase[clinicId]?[serviceKey] ?? 
           {'name': 'Dr. Available', 'role': 'General Dentist'};
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

  // --- Location Selection Modal ---
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Clinic Location",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _clinics.length,
                  separatorBuilder: (_,_) => const SizedBox(height: 15),
                  itemBuilder: (context, index) {
                    final clinic = _clinics[index];
                    final isSelected = _selectedClinicIndex == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedClinicIndex = index;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFBC02D) : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Small Image Thumbnail
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                              child: Image.asset(
                                clinic['image'],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 80, 
                                    height: 80, 
                                    color: Colors.grey[200], 
                                    child: const Icon(Icons.image_not_supported, color: Colors.grey)
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Text Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppTranslations.get(clinic['nameKey']),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    clinic['address'],
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Padding(
                                padding: EdgeInsets.only(right: 12.0),
                                child: Icon(Icons.check_circle, color: Color(0xFFFBC02D)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctor = _getDoctorInfo(); // This now updates when _selectedClinicIndex changes
    final Color primaryYellow = const Color(0xFFFBC02D);
    final selectedClinic = _clinics[_selectedClinicIndex];

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
                  // --- Consulting Doctor Section (Top) ---
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
                        // Avatar Removed per instructions
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

                  // --- Select Location Section (Below Doctor) ---
                  const Text(
                    'Select Location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: _showLocationPicker,
                    child: Container(
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
                          const Icon(Icons.location_on, color: Color(0xFFFBC02D), size: 24),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppTranslations.get(selectedClinic['nameKey']),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  selectedClinic['address'],
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- Date Selection ---
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

                  // --- Time Selection ---
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

          // --- Bottom Confirm Button ---
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
                        // Navigate to ReviewConfirmView and pass the DYNAMICALLY selected doctor name
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReviewConfirmView(
                              clinicNameKey: selectedClinic['nameKey'],
                              clinicAddress: selectedClinic['address'],
                              serviceName: widget.serviceName,
                              servicePrice: widget.servicePrice ?? "RM 0",
                              date: _selectedDate,
                              time: _selectedTime!,
                              doctorName: doctor['name']!, 
                            ),
                          ),
                        );
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