import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RescheduleView extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const RescheduleView({super.key, required this.appointment});

  @override
  State<RescheduleView> createState() => _RescheduleViewState();
}

class _RescheduleViewState extends State<RescheduleView> {
  // --- State ---
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  bool _isLoading = true;
  bool _checkingAvailability = false;
  int _appointmentCountForDate = 0;
  Set<String> _bookedTimeSlots = {};

  final List<String> _timeSlots = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', 
    '11:00 AM', '02:00 PM', '02:30 PM', '03:00 PM', '04:00 PM',
    '05:00 PM', '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM'
  ];

  @override
  void initState() {
    super.initState();
    // Initialize date from appointment or tomorrow
    try {
      final currentDt = DateTime.parse(widget.appointment['appointment_datetime']).toLocal();
      if (currentDt.isAfter(DateTime.now())) {
        _selectedDate = currentDt;
      }
    } catch (_) {}
    
    _checkDateAvailability(_selectedDate);
  }

  Future<void> _checkDateAvailability(DateTime date) async {
    setState(() => _checkingAvailability = true);

    try {
      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final response = await Supabase.instance.client
          .from('Appointment')
          .select('appointment_datetime')
          .eq('doctor_id', widget.appointment['doctor_id']) // Filter by Doctor ID
          .gte('appointment_datetime', startOfDay.toUtc().toIso8601String())
          .lte('appointment_datetime', endOfDay.toUtc().toIso8601String())
          .neq('status', 'Cancelled')
          .neq('status', 'Completed')
          .neq('status', 'Expired');

      final List<dynamic> data = response as List<dynamic>;
      
      Set<String> booked = {};
      for (var item in data) {
        final String? dtStr = item['appointment_datetime'];
        if (dtStr != null) {
          final dt = DateTime.parse(dtStr).toLocal();
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
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking availability: $e');
      if (mounted) setState(() { _checkingAvailability = false; _isLoading = false; });
    }
  }

  bool _isTimeSlotAvailable(String timeSlot) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (selected.isAfter(today)) return true;
    if (selected.isBefore(today)) return false;

    // It's Today
    try {
      final parts = timeSlot.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      final amPm = parts[1];

      if (amPm == 'PM' && hour != 12) hour += 12;
      if (amPm == 'AM' && hour == 12) hour = 0;

      final slotDateTime = DateTime(now.year, now.month, now.day, hour, minute);
      return slotDateTime.isAfter(now);
    } catch (e) {
      return true;
    }
  }

  void _confirmSelection() {
    if (_selectedTime == null) return;
    
    // Convert to Date + Time
    final parts = _selectedTime!.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);
    final amPm = parts[1];

    if (amPm == 'PM' && hour != 12) hour += 12;
    if (amPm == 'AM' && hour == 12) hour = 0;

    final newDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);
    
    Navigator.pop(context, newDateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Select New Time"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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
                          _selectedTime = null;
                        });
                        _checkDateAvailability(date);
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'Available Time',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  
                  if (_checkingAvailability || _isLoading)
                    const Center(child: CircularProgressIndicator(color: Color(0xFFFBC02D)))
                  else if (_appointmentCountForDate >= 5)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.event_busy, color: Colors.red, size: 40),
                          SizedBox(height: 10),
                          Text(
                            "Date Fully Booked",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                    )
                  else
                    Builder(
                      builder: (context) {
                        final availableSlots = _timeSlots.where((time) => 
                          _isTimeSlotAvailable(time) && !_bookedTimeSlots.contains(time)
                        ).toList();
                        
                        if (availableSlots.isEmpty) {
                           return const Center(child: Text("No slots available for this date."));
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
                onPressed: _selectedTime != null ? _confirmSelection : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBC02D),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Confirm New Time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
