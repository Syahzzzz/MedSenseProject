import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffAppointmentsView extends StatefulWidget {
  const StaffAppointmentsView({super.key});

  @override
  State<StaffAppointmentsView> createState() => _StaffAppointmentsViewState();
}

class _StaffAppointmentsViewState extends State<StaffAppointmentsView> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  
  // Tab Controller
  late TabController _tabController;

  // Theme Colors
  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // Fetch appointments with joined tables
      final response = await _supabase
          .from('Appointment')
          .select('*, Patient(name), Doctor(name), Service(service_name)')
          .order('appointment_datetime', ascending: false); // Newest first

      if (mounted) {
        setState(() {
          _appointments = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading appointments: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(String appointmentId, String newStatus) async {
    try {
      await _supabase
          .from('Appointment')
          .update({'status': newStatus})
          .eq('appointment_id', appointmentId);

      // Send Notification if Cancelled
      if (newStatus == 'Cancelled') {
        try {
          final apt = _appointments.firstWhere((a) => a['appointment_id'] == appointmentId, orElse: () => {});
          final patientId = apt['patient_id'];
          
          if (patientId != null) {
            await _supabase.from('Notification').insert({
              'recipient_id': patientId,
              'message_content': 'Your appointment has been cancelled. A refund has been processed to your account.',
              'is_read': false,
            });
          }
        } catch (e) {
          debugPrint('Error sending notification: $e');
        }
      }

      // Send Notification if Confirmed
      if (newStatus == 'Confirmed') {
        try {
          final apt = _appointments.firstWhere((a) => a['appointment_id'] == appointmentId, orElse: () => {});
          final patientId = apt['patient_id'];
          
          if (patientId != null) {
            await _supabase.from('Notification').insert({
              'recipient_id': patientId,
              'message_content': 'Your appointment has been approved.',
              'is_read': false,
            });
          }
        } catch (e) {
          debugPrint('Error sending notification: $e');
        }
      }

      // Refresh list locally
      final index = _appointments.indexWhere((a) => a['appointment_id'] == appointmentId);
      if (index != -1) {
        setState(() {
          _appointments[index]['status'] = newStatus;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus')),
        );
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _filterAppointments(String category) {
    final now = DateTime.now();
    
    if (category == 'Upcoming') {
      // Confirmed appointments in the future
      return _appointments.where((a) {
        final status = a['status'] as String? ?? '';
        final dt = DateTime.parse(a['appointment_datetime']);
        return (status == 'Confirmed' || status == 'Pending') && dt.isAfter(now);
      }).toList();
    } else if (category == 'Today') {
       return _appointments.where((a) {
        final dt = DateTime.parse(a['appointment_datetime']).toLocal();
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      }).toList();
    } else {
      // History: Completed, Cancelled, Expired, or Past Confirmed
      return _appointments.where((a) {
        final status = a['status'] as String? ?? '';
        final dt = DateTime.parse(a['appointment_datetime']);
        return status == 'Completed' || status == 'Cancelled' || status == 'Expired' || dt.isBefore(now);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Appointments', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _primaryYellow,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Upcoming'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: _primaryYellow))
        : TabBarView(
            controller: _tabController,
            children: [
              _buildAppointmentList('Today'),
              _buildAppointmentList('Upcoming'),
              _buildAppointmentList('History'),
            ],
          ),
    );
  }

  Widget _buildAppointmentList(String category) {
    final filtered = _filterAppointments(category);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text("No $category appointments", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAppointments,
      color: _primaryYellow,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final apt = filtered[index];
          return _buildAppointmentCard(apt);
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> apt) {
    final patientName = apt['Patient']?['name'] ?? 'Unknown Patient';
    final doctorName = apt['Doctor']?['name'] ?? 'Assigned Doctor';
    final serviceName = apt['Service']?['service_name'] ?? 'General Service';
    final status = apt['status'] ?? 'Unknown';
    
    // Date Formatting
    final dt = DateTime.parse(apt['appointment_datetime']).toLocal();
    final dateStr = "${dt.day}/${dt.month}/${dt.year}";
    
    int hour = dt.hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final timeStr = "$hour:$minuteStr $amPm";

    String displayStatus = status;
    if (status == 'Pending') {
       displayStatus = 'Pending Review';
    }

    Color statusColor;
    switch (status) {
      case 'Confirmed': statusColor = Colors.green;
      case 'Pending': statusColor = Colors.orange;
      case 'Completed': statusColor = Colors.blue;
      case 'Cancelled': statusColor = Colors.red;
      default: statusColor = Colors.grey;
    }

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date & Time + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 5),
                    Text("$dateStr • $timeStr", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    displayStatus.toUpperCase(), 
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            
            // Body: Patient, Service, Doctor
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _primaryYellow.withValues(alpha: 0.2),
                  child: Text(patientName[0].toUpperCase(), style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(serviceName, style: TextStyle(color: Colors.grey[800], fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(" $doctorName", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                
                // Actions Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'FollowUp') {
                      _createFollowUp(apt);
                    } else {
                      _updateStatus(apt['appointment_id'], value);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'Confirmed', child: Text('Mark Confirmed')),
                    const PopupMenuItem(value: 'Completed', child: Text('Mark Completed')),
                    const PopupMenuItem(value: 'Cancelled', child: Text('Cancel Appointment')),
                    const PopupMenuItem(value: 'No Show', child: Text('No Show')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'FollowUp', child: Text('Create Follow-up')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFollowUp(Map<String, dynamic> sourceApt) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)), // Suggest next month
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: _primaryYellow),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: _primaryYellow),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    final DateTime finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!mounted) return;

    final String formattedTime = pickedTime.format(context);

    setState(() => _isLoading = true);

    try {
      final String patientId = sourceApt['patient_id'];
      final String? doctorId = sourceApt['doctor_id'];
      final String? serviceId = sourceApt['service_id'];
      final String serviceName = sourceApt['Service']?['service_name'] ?? 'Service';

      // 1. Insert New Appointment
      await _supabase.from('Appointment').insert({
        'patient_id': patientId,
        'doctor_id': doctorId,
        'service_id': serviceId,
        'appointment_datetime': finalDateTime.toIso8601String(),
        'status': 'Confirmed', // Auto-confirm staff created appointments
        'predicted_wait_time_minutes': 0,
      });

      // 2. Send Notification
      final dateStr = "${finalDateTime.day}/${finalDateTime.month}/${finalDateTime.year}";
      
      await _supabase.from('Notification').insert({
        'recipient_id': patientId,
        'message_content': 'A follow-up appointment for $serviceName has been scheduled for $dateStr at $formattedTime by the clinic.',
        'is_read': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow-up appointment created successfully')),
        );
        await _fetchAppointments(); // Refresh list
      }
    } catch (e) {
      debugPrint('Error creating follow-up: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating follow-up: $e')),
        );
      }
    }
  }
}
