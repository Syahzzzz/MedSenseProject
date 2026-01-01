import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalkInRegistrationView extends StatefulWidget {
  const WalkInRegistrationView({super.key});

  @override
  State<WalkInRegistrationView> createState() => _WalkInRegistrationViewState();
}

class _WalkInRegistrationViewState extends State<WalkInRegistrationView> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Data Sources
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _patients = [];

  // Doctor Availability
  Map<String, String> _doctorStatusMap = {};
  Map<String, int> _doctorQueueCounts = {};
  List<Map<String, dynamic>> _dailyAppointments = [];

  // Room Management
  final List<int> _allRooms = [101, 102, 103, 104, 105];
  List<int> _busyRooms = [];

  // Selections
  String? _selectedPatientId;
  String? _selectedDoctorId;
  String? _selectedServiceId;
  int? _selectedRoom;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _fetchAppointmentsForDate(_selectedDate);
  }

  Future<void> _fetchAppointmentsForDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final res = await _supabase
          .from('Appointment')
          .select('doctor_id, appointment_datetime, Service(estimated_duration_minutes)')
          .gte('appointment_datetime', startOfDay.toIso8601String())
          .lt('appointment_datetime', endOfDay.toIso8601String())
          .neq('status', 'Cancelled'); // Exclude cancelled

      if (mounted) {
        setState(() {
          _dailyAppointments = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('Error fetching daily appointments: $e');
    }
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final doctors = await _supabase.from('Doctor').select('doctor_id, name, specialization').order('name');
      final services = await _supabase.from('Service').select('service_id, service_name, price').order('service_name');
      
      // Fetch Busy Rooms (Serving or Waiting)
      final activeQueues = await _supabase
          .from('QueueEntry')
          .select('assigned_room, doctor_id, status')
          .or('status.eq.Waiting,status.eq.Serving');
      
      final busyList = activeQueues
          .map((q) => q['assigned_room'] as int?)
          .where((r) => r != null)
          .cast<int>()
          .toSet() // Unique
          .toList();

      // Process Doctor Status
      final Map<String, String> statusMap = {};
      final Map<String, int> queueCounts = {};

      for (var q in activeQueues) {
        final docId = q['doctor_id'] as String?;
        if (docId == null) continue;

        // Count queue
        queueCounts[docId] = (queueCounts[docId] ?? 0) + 1;

        // Check if serving
        if (q['status'] == 'Serving') {
          statusMap[docId] = 'Serving';
        }
      }

      if (mounted) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(doctors);
          _services = List<Map<String, dynamic>>.from(services);
          _busyRooms = busyList;
          _doctorStatusMap = statusMap;
          _doctorQueueCounts = queueCounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchPatients(String query) async {
    if (query.isEmpty) {
      setState(() => _patients = []);
      return;
    }
    
    setState(() => _isSearching = true);
    try {
      final res = await _supabase
          .from('Patient')
          .select('patient_id, name, phone_number, email')
          .ilike('name', '%$query%')
          .limit(10);
      
      if (mounted) {
        setState(() {
          _patients = List<Map<String, dynamic>>.from(res);
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate() || _selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient and fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Combine selected date with selected time
      final finalDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // 1. Create Appointment
      final appointmentRes = await _supabase.from('Appointment').insert({
        'patient_id': _selectedPatientId,
        'doctor_id': _selectedDoctorId,
        'service_id': _selectedServiceId,
        'appointment_datetime': finalDateTime.toIso8601String(),
        'status': 'Confirmed', // Or 'Arrived'
        'payment_status': 'Unpaid',
        'payment_method': 'Pay at Venue',
        'notes': 'Walk-in Registration',
      }).select().single();

      final appointmentId = appointmentRes['appointment_id'];

      // 2. Determine Queue Number
      final maxQueueRes = await _supabase
          .from('QueueEntry')
          .select('queue_number')
          .order('queue_number', ascending: false)
          .limit(1)
          .maybeSingle();
      
      int nextQueueNumber = 1;
      if (maxQueueRes != null) {
        nextQueueNumber = (maxQueueRes['queue_number'] as int) + 1;
      }

      // 3. Create Queue Entry
      await _supabase.from('QueueEntry').insert({
        'patient_id': _selectedPatientId,
        'doctor_id': _selectedDoctorId,
        'service_id': _selectedServiceId,
        'appointment_id': appointmentId,
        'queue_number': nextQueueNumber,
        'assigned_room': _selectedRoom,
        'status': 'Waiting',
        'check_in_time': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Walk-in registered! Queue #$nextQueueNumber')),
        );
        Navigator.pop(context); // Return to dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error registering: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryYellow = Color(0xFFFBC02D);

    // If selected room became busy (e.g. reload), reset selection
    if (_selectedRoom != null && !_allRooms.contains(_selectedRoom)) {
       _selectedRoom = null;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Walk-In Registration', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading && _doctors.isEmpty 
          ? const Center(child: CircularProgressIndicator(color: primaryYellow))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Patient Details",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    // Patient Search
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: "Search Patient Name",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching 
                            ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)) 
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) => _searchPatients(val),
                    ),
                    if (_patients.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _patients.length,
                          itemBuilder: (context, index) {
                            final p = _patients[index];
                            final isSelected = p['patient_id'] == _selectedPatientId;
                            return ListTile(
                              title: Text(p['name']),
                              subtitle: Text(p['phone_number']),
                              tileColor: isSelected ? primaryYellow.withValues(alpha: 0.1) : null,
                              trailing: isSelected ? const Icon(Icons.check, color: primaryYellow) : null,
                              onTap: () {
                                setState(() {
                                  _selectedPatientId = p['patient_id'];
                                  _searchController.text = p['name']; // Set text to name
                                  _patients = []; // Hide list
                                });
                              },
                            );
                          },
                        ),
                      ),
                    
                    if (_selectedPatientId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Selected Patient ID: ...${_selectedPatientId!.substring(_selectedPatientId!.length - 6)}",
                          style: TextStyle(color: Colors.green[700], fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 30),
                    const Text(
                      "Visit Details",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // Date Selection
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: primaryYellow)),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                          _fetchAppointmentsForDate(picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(Icons.calendar_today, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Time Selection
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: primaryYellow)),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setState(() => _selectedTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Time: ${_selectedTime.format(context)}",
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(Icons.access_time, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Service Dropdown
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedServiceId,
                      decoration: InputDecoration(
                        labelText: "Select Service",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.medical_services_outlined),
                      ),
                      items: _services.map((s) {
                        return DropdownMenuItem<String>(
                          value: s['service_id'],
                          child: Text(
                            s['service_name'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedServiceId = val),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),

                    // Doctor Dropdown
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedDoctorId,
                      decoration: InputDecoration(
                        labelText: "Select Doctor",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      items: _doctors.map((d) {
                        final id = d['doctor_id'];
                        final isServing = _doctorStatusMap[id] == 'Serving';
                        final count = _doctorQueueCounts[id] ?? 0;
                        
                        // Check if booked at selected time
                        bool isBooked = false;
                        for (var appt in _dailyAppointments) {
                          if (appt['doctor_id'] == id) {
                            final apptTime = DateTime.parse(appt['appointment_datetime']).toLocal();
                            final duration = appt['Service']?['estimated_duration_minutes'] ?? 30;
                            
                            final selectedDateTime = DateTime(
                              _selectedDate.year, _selectedDate.month, _selectedDate.day,
                              _selectedTime.hour, _selectedTime.minute
                            );
                            
                            final apptEnd = apptTime.add(Duration(minutes: duration));
                            
                            // Check overlap (simple check: if selected time is within an existing appointment window)
                            if (selectedDateTime.isAtSameMomentAs(apptTime) || 
                                (selectedDateTime.isAfter(apptTime) && selectedDateTime.isBefore(apptEnd))) {
                              isBooked = true;
                              break;
                            }
                          }
                        }

                        String statusText = "";
                        if (isServing) {
                          statusText = " (Serving)";
                        } else if (isBooked) {
                          statusText = " (Booked)";
                        } else if (count > 0) {
                          statusText = " ($count waiting)";
                        } else {
                          statusText = " (Available)";
                        }

                        final bool isDisabled = isServing || isBooked;

                        return DropdownMenuItem<String>(
                          value: id,
                          enabled: !isDisabled,
                          child: Text(
                            "${d['name']} -$statusText",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDisabled ? Colors.grey : (count > 0 ? Colors.orange : Colors.green[700]),
                              decoration: isDisabled ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        // For now, standard Dropdown behavior prevents selecting disabled items.
                        if (val != null) setState(() => _selectedDoctorId = val);
                      },
                      validator: (val) {
                        if (val == null) return 'Required';
                        if (_doctorStatusMap[val] == 'Serving') return 'Doctor is busy';
                        // We could add 'Doctor is booked' check here too if we want strict validation
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Room Dropdown
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _selectedRoom,
                      decoration: InputDecoration(
                        labelText: "Select Room",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.room_outlined),
                        helperText: _busyRooms.isNotEmpty 
                            ? "Busy Rooms: ${_busyRooms.join(', ')}" 
                            : "All rooms available"
                      ),
                      items: _allRooms.map((r) {
                        final isBusy = _busyRooms.contains(r);
                        return DropdownMenuItem<int>(
                          value: isBusy ? null : r, // Disable selection if busy? No, null value item behaves weirdly.
                          // Better: Just don't include it in the list if we want to prevent selection?
                          // The user said "cannot be selected".
                          // If we map to null, it might be unselectable or error.
                          // Standard flutter dropdown: if value matches, it's selected. 
                          // To DISABLE an item, we usually put 'enabled: false' in DropdownMenuItem.
                          enabled: !isBusy,
                          child: Text(
                            "Room $r ${isBusy ? '(Occupied)' : ''}",
                            style: TextStyle(color: isBusy ? Colors.grey : Colors.black),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                         if (val != null) setState(() => _selectedRoom = val);
                      },
                      validator: (val) => val == null ? 'Required' : null,
                    ),

                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryYellow,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              "Register Walk-In",
                              style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}