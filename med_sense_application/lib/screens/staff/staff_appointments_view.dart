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
    // Check if currently Cancelled
    final currentApt = _appointments.firstWhere((a) => a['appointment_id'] == appointmentId, orElse: () => {});
    if (currentApt.isNotEmpty && currentApt['status'] == 'Cancelled') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot change status. Appointment is already cancelled and refund processed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final updates = {'status': newStatus};
      
      // If cancelling, set payment status to Refunded
      if (newStatus == 'Cancelled') {
        updates['payment_status'] = 'Refunded';
      }

      await _supabase
          .from('Appointment')
          .update(updates)
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
          if (newStatus == 'Cancelled') {
             _appointments[index]['payment_status'] = 'Refunded';
          }
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

  Future<void> _updatePaymentStatus(String appointmentId, String newPaymentStatus) async {
    try {
      await _supabase
          .from('Appointment')
          .update({'payment_status': newPaymentStatus})
          .eq('appointment_id', appointmentId);

      // Refresh list locally
      final index = _appointments.indexWhere((a) => a['appointment_id'] == appointmentId);
      if (index != -1) {
        setState(() {
          _appointments[index]['payment_status'] = newPaymentStatus;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment status updated to $newPaymentStatus')),
        );
      }
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating payment status: $e')),
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
    final paymentStatus = apt['payment_status'] ?? 'Unpaid'; // Default Unpaid
    final paymentMethod = apt['payment_method'] ?? 'Unknown Method';
    
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

    Color paymentColor = paymentStatus == 'Paid' ? Colors.green : Colors.red;

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
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          "$dateStr • $timeStr",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Payment Status Badge
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: paymentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: paymentColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        paymentStatus.toUpperCase(), 
                        style: TextStyle(color: paymentColor, fontSize: 10, fontWeight: FontWeight.bold)
                      ),
                    ),
                    // Appointment Status Badge
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
                      const SizedBox(height: 4),
                      Row(
                         children: [
                           Icon(Icons.payment, size: 14, color: Colors.grey[600]),
                           const SizedBox(width: 4),
                           Expanded(
                             child: Text(
                               paymentMethod, 
                               style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                         ],
                      ),
                    ],
                  ),
                ),
                
                // Actions Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'FollowUp') {
                      _createFollowUp(apt);
                    } else if (value == 'MarkPaid') {
                      _updatePaymentStatus(apt['appointment_id'], 'Paid');
                    } else if (value == 'MarkUnpaid') {
                      _updatePaymentStatus(apt['appointment_id'], 'Unpaid');
                    } else {
                      _updateStatus(apt['appointment_id'], value);
                    }
                  },
                  itemBuilder: (context) {
                    final isCancelled = status == 'Cancelled';
                    return [
                      PopupMenuItem(
                        value: 'Confirmed', 
                        enabled: !isCancelled,
                        child: const Text('Mark Confirmed'),
                      ),
                      PopupMenuItem(
                        value: 'Completed', 
                        enabled: !isCancelled,
                        child: const Text('Mark Completed'),
                      ),
                      PopupMenuItem(
                        value: 'Cancelled', 
                        enabled: !isCancelled,
                        child: const Text('Cancel Appointment'),
                      ),
                      PopupMenuItem(
                        value: 'No Show', 
                        enabled: !isCancelled,
                        child: const Text('No Show'),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'MarkPaid', 
                        enabled: !isCancelled,
                        child: const Text('Mark as Paid'),
                      ),
                      PopupMenuItem(
                        value: 'MarkUnpaid', 
                        enabled: !isCancelled,
                        child: const Text('Mark as Unpaid'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'FollowUp', child: Text('Create Follow-up')),
                    ];
                  },
                ),
              ],
            ),
            
            // Inline History Tree View
            _buildTimelineWidget(apt),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineWidget(Map<String, dynamic> currentApt) {
    // 1. Find Ancestors
    List<Map<String, dynamic>> chain = [];
    String? prevId = currentApt['previous_appointment_id'];
    
    // Safety break to prevent infinite loops in bad data
    int depth = 0;
    while (prevId != null && depth < 10) {
      final ancestorIndex = _appointments.indexWhere((a) => a['appointment_id'] == prevId);
      if (ancestorIndex != -1) {
        final ancestor = _appointments[ancestorIndex];
        chain.insert(0, ancestor); // Add to beginning (oldest first)
        prevId = ancestor['previous_appointment_id'];
        depth++;
      } else {
        break; // Ancestor not found in loaded list
      }
    }

    if (chain.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        const Text(
          "Appointment History",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        ...chain.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          final dt = DateTime.parse(item['appointment_datetime']).toLocal();
          final dateStr = "${dt.day}/${dt.month}/${dt.year}";
          final serviceName = item['Service']?['service_name'] ?? 'Service';
          final status = item['status'] ?? 'Unknown';

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                        border: Border.all(color: Colors.grey[500]!),
                      ),
                    ),
                    if (index < chain.length - 1 || true) // Draw line to next or current
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.grey[300],
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$dateStr - $serviceName",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                        ),
                        Text(
                          "Status: $status",
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        // Connection to current (The "This Appointment" indicator)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _primaryYellow,
                      border: Border.all(color: Colors.black),
                    ),
                  ),
                ],
             ),
             const SizedBox(width: 12),
             const Text("This Appointment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        )
      ],
    );
  }

  Future<void> _createFollowUp(Map<String, dynamic> sourceApt) async {
    DateTime? selectedDate = DateTime.now().add(const Duration(days: 30));
    TimeOfDay? selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final TextEditingController notesController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    
    // Fetch Doctors
    List<Map<String, dynamic>> doctors = [];
    String? selectedDoctorId = sourceApt['doctor_id']; // Default to current doctor
    try {
      final docRes = await _supabase.from('Doctor').select('doctor_id, name').order('name');
      doctors = List<Map<String, dynamic>>.from(docRes);
      
      // Ensure selectedDoctorId exists in the list, otherwise default to first or null
      if (selectedDoctorId != null && !doctors.any((d) => d['doctor_id'] == selectedDoctorId)) {
         selectedDoctorId = doctors.isNotEmpty ? doctors.first['doctor_id'] : null;
      }
    } catch (e) {
      debugPrint("Error fetching doctors: $e");
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dateStr = "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}";
            final timeStr = selectedTime!.format(context);

            return AlertDialog(
              title: const Text("Create Follow-up"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Select Doctor:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDoctorId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: doctors.map((doc) {
                        return DropdownMenuItem<String>(
                          value: doc['doctor_id'],
                          child: Text(doc['name'] ?? 'Unknown'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedDoctorId = val),
                    ),
                    const SizedBox(height: 15),
                    const Text("Select Date & Time:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ListTile(
                      title: Text(dateStr),
                      leading: const Icon(Icons.calendar_today),
                      tileColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate!,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: _primaryYellow)),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => selectedDate = picked);
                      },
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      title: Text(timeStr),
                      leading: const Icon(Icons.access_time),
                      tileColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime!,
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: _primaryYellow)),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => selectedTime = picked);
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text("Custom Price (Optional):", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: "Enter price (RM)",
                        prefixText: "RM ",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text("Reason / Notes:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: "E.g., Check braces progress...",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryYellow,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text("Create"),
                  onPressed: () {
                    // Close dialog and proceed
                     Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((confirmed) async {
       if (confirmed == true) {
          final DateTime finalDateTime = DateTime(
            selectedDate!.year,
            selectedDate!.month,
            selectedDate!.day,
            selectedTime!.hour,
            selectedTime!.minute,
          );

          if (!mounted) return;
          final String formattedTime = selectedTime!.format(context);
          final String notes = notesController.text.trim();
          final String priceStr = priceController.text.trim();
          double? customPrice;
          if (priceStr.isNotEmpty) {
             customPrice = double.tryParse(priceStr);
          }

          setState(() => _isLoading = true);

          try {
            final String patientId = sourceApt['patient_id'];
            // Use selected doctor ID
            final String? doctorId = selectedDoctorId;
            final String? serviceId = sourceApt['service_id'];
            final String serviceName = sourceApt['Service']?['service_name'] ?? 'Service';

            // 1. Insert New Appointment
            await _supabase.from('Appointment').insert({
              'patient_id': patientId,
              'doctor_id': doctorId,
              'service_id': serviceId,
              'appointment_datetime': finalDateTime.toIso8601String(),
              'status': 'Confirmed', // Auto-confirm staff created appointments
              'payment_status': 'Unpaid', // Default for follow-ups
              'payment_method': 'Pay at Venue', // Default for follow-ups
              'previous_appointment_id': sourceApt['appointment_id'], // Link to source
              'predicted_wait_time_minutes': 0,
              'notes': notes,
              'custom_price': customPrice,
            });

            // 2. Send Notification
            final dateStr = "${finalDateTime.day}/${finalDateTime.month}/${finalDateTime.year}";
            String msg = 'A follow-up appointment for $serviceName has been scheduled for $dateStr at $formattedTime by the clinic.';
            if (notes.isNotEmpty) {
              msg += ' Reason: $notes';
            }
            if (customPrice != null) {
              msg += ' Price: RM $customPrice';
            }
            
            await _supabase.from('Notification').insert({
              'recipient_id': patientId,
              'message_content': msg,
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
    });
  }


}
