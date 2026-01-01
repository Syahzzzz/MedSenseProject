import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_sense_application/screens/patient/dashboard.dart';
import 'package:med_sense_application/utils/translations.dart';
import 'package:med_sense_application/screens/booking/review_confirm_view.dart';

class BookingDateTimeView extends StatefulWidget {
  final String serviceName;
  final String? servicePrice;
  final String description; // Added to pass breakdown details

  const BookingDateTimeView({
    super.key,
    required this.serviceName,
    this.servicePrice,
    required this.description,
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

  // --- State ---
  int _selectedClinicIndex = 0; // Default to first clinic
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  List<Map<String, dynamic>> _allDoctors = [];
  Map<String, dynamic>? _assignedDoctor;
  
  // Availability State
  int _appointmentCountForDate = 0;
  Set<String> _bookedTimeSlots = {}; // Store booked times
  bool _checkingAvailability = false;
  
  // Realtime
  RealtimeChannel? _appointmentsChannel;

  final List<String> _timeSlots = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', 
    '11:00 AM', '02:00 PM', '02:30 PM', '03:00 PM', '04:00 PM',
    '05:00 PM', '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM'
  ];

  @override
  void initState() {
    super.initState();
    _fetchDoctors(); // This will trigger availability check once doctor is assigned
    _subscribeToAppointments();
  }

  @override
  void dispose() {
    _appointmentsChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToAppointments() {
    _appointmentsChannel = Supabase.instance.client
        .channel('public:Appointment:BookingView')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Appointment',
          callback: (payload) {
            // Refresh availability whenever any appointment changes
            _checkDateAvailability(_selectedDate);
          },
        )
        .subscribe();
  }

  Future<void> _checkDateAvailability(DateTime date) async {
    // If no doctor is assigned yet, we can't check specific availability
    if (_assignedDoctor == null) return;

    setState(() => _checkingAvailability = true);

    try {
      // Create range for the entire day (Local -> UTC)
      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Fetch appointment_datetime to identify occupied slots for THIS doctor
      final query = Supabase.instance.client
          .from('Appointment')
          .select('appointment_datetime')
          .eq('doctor_id', _assignedDoctor!['doctor_id']) // Filter by Doctor ID
          .gte('appointment_datetime', startOfDay.toUtc().toIso8601String())
          .lte('appointment_datetime', endOfDay.toUtc().toIso8601String())
          .neq('status', 'Cancelled')
          .neq('status', 'Completed')
          .neq('status', 'Expired');

      final response = await query;

      final List<dynamic> data = response as List<dynamic>;
      
      // Process booked times
      Set<String> booked = {};
      for (var item in data) {
        final String? dtStr = item['appointment_datetime'];
        if (dtStr != null) {
          final dt = DateTime.parse(dtStr).toLocal();
          
          // Format to "hh:mm AM/PM" to match _timeSlots
          int hour = dt.hour;
          final String amPm = hour >= 12 ? 'PM' : 'AM';
          
          if (hour > 12) hour -= 12;
          if (hour == 0) hour = 12;

          final String hourStr = hour.toString().padLeft(2, '0');
          final String minStr = dt.minute.toString().padLeft(2, '0');
          
          booked.add('$hourStr:$minStr $amPm');
        }
      }

      if (mounted) {
        setState(() {
          _appointmentCountForDate = data.length;
          _bookedTimeSlots = booked;
          _checkingAvailability = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking availability: $e');
      if (mounted) setState(() => _checkingAvailability = false);
    }
  }

  Future<void> _fetchDoctors() async {
    try {
      final response = await Supabase.instance.client
          .from('Doctor')
          .select('doctor_id, name, specialization'); // Added doctor_id
      
      if (mounted) {
        setState(() {
          _allDoctors = List<Map<String, dynamic>>.from(response);
          _selectDoctor(); // Select doctor immediately after fetching
        });
        
        // Check availability now that we have a doctor
        _checkDateAvailability(_selectedDate);
      }
    } catch (e) {
      debugPrint('Error fetching doctors: $e');
    }
  }

  // Select the correct doctor based on Service and store in state
  void _selectDoctor() {
    if (_allDoctors.isEmpty) {
      _assignedDoctor = {'name': 'Dr. Available', 'specialization': 'General Dentist', 'doctor_id': null};
      return;
    }

    final String serviceKey = _getServiceKey();
    
    try {
      // Filter all doctors that match the specialization criteria
      final matchingDoctors = _allDoctors.where((doc) {
        final String spec = (doc['specialization'] as String? ?? '').toLowerCase();
        final String sKey = serviceKey.toLowerCase();
        
        if (sKey == 'braces' && (spec.contains('ortho') || spec.contains('braces'))) return true;
        if (sKey == 'scaling' && (spec.contains('surgeon') || spec.contains('general') || spec.contains('hygienist'))) return true;
        if (sKey == 'whitening' && (spec.contains('aesthetic') || spec.contains('cosmetic') || spec.contains('general'))) return true;
        if (sKey == 'retainers' && (spec.contains('ortho') || spec.contains('general'))) return true;
        
        return false;
      }).toList();

      if (matchingDoctors.isNotEmpty) {
        // Use hash of service name to pick a doctor from the matches
        // This ensures different services get different doctors (if available) but stays consistent for the same service
        final int index = widget.serviceName.hashCode.abs() % matchingDoctors.length;
        _assignedDoctor = matchingDoctors[index];
      } else {
        // Fallback: Pick a doctor from the full list using the same hash logic
        final int index = widget.serviceName.hashCode.abs() % _allDoctors.length;
        _assignedDoctor = _allDoctors[index];
      }
    } catch (e) {
      _assignedDoctor = _allDoctors.first;
    }
  }

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

  // --- Helper to check if time slot is in the future ---
  bool _isTimeSlotAvailable(String timeSlot) {
    final now = DateTime.now();
    // Compare dates strictly (ignoring time)
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (selected.isAfter(today)) {
      return true; // Future date: all slots open
    }
    if (selected.isBefore(today)) {
      return false; // Past date: no slots
    }

    // It's Today: Check time
    try {
      final parts = timeSlot.split(' '); // e.g. ["09:00", "AM"]
      final timeParts = parts[0].split(':'); // ["09", "00"]
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      final amPm = parts[1];

      if (amPm == 'PM' && hour != 12) hour += 12;
      if (amPm == 'AM' && hour == 12) hour = 0;

      final slotDateTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      // Return true if slot is in the future
      return slotDateTime.isAfter(now);
    } catch (e) {
      return true; // Fallback
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
    final doctor = _assignedDoctor ?? {'name': 'Loading...', 'specialization': 'Loading...'};
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
                                doctor['specialization'] ?? 'Dentist',
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
                          _selectedTime = null; // Reset time when date changes
                          // Check if selected time is still valid, else clear it
                          // (Logic moved to availability check mostly, but ensuring reset is safer)
                        });
                        _checkDateAvailability(date);
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
                  Builder(
                    builder: (context) {
                      if (_checkingAvailability) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFFFBC02D)));
                      }

                      // Check Limit
                      if (_appointmentCountForDate >= 5) {
                         return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.event_busy, color: Colors.red, size: 40),
                              const SizedBox(height: 10),
                              const Text(
                                "Date Fully Booked",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "This date has reached the maximum number of appointments (5). Please select another date.",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.red[800]),
                              ),
                            ],
                          ),
                        );
                      }

                      // Filter out past times AND booked times
                      final availableSlots = _timeSlots.where((time) => 
                        _isTimeSlotAvailable(time) && !_bookedTimeSlots.contains(time)
                      ).toList();
                      
                      if (availableSlots.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.access_time_filled, color: Colors.grey, size: 40),
                              const SizedBox(height: 10),
                              const Text(
                                "No slots available",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Please select another date.",
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 10,
                        runSpacing: 12,
                        children: availableSlots.map((time) {
                          bool isSelected = _selectedTime == time;
                          return ChoiceChip(
                            label: Text(time),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFBC02D),
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
                      );
                    }
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
                              description: widget.description, // Pass description
                              date: _selectedDate,
                              time: _selectedTime!,
                              doctorName: doctor['name']!,
                              doctorId: doctor['doctor_id'],
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