import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffRequestsView extends StatefulWidget {
  const StaffRequestsView({super.key});

  @override
  State<StaffRequestsView> createState() => _StaffRequestsViewState();
}

class _StaffRequestsViewState extends State<StaffRequestsView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final response = await _supabase
          .from('Appointment')
          .select('*, Patient(name, phone_number), Service(service_name)')
          .or('status.eq.Cancellation Requested,status.eq.Reschedule Requested')
          .order('appointment_datetime', ascending: true);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching requests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processRequest(String id, String type, bool approve, {String? newDateStr}) async {
    try {
      Map<String, dynamic> updates = {};
      String notificationMessage = "";

      // Find the request to get patient_id
      final req = _requests.firstWhere((r) => r['appointment_id'] == id);
      final patientId = req['patient_id'];

      if (type == 'Cancellation Requested') {
        if (approve) {
           // Approve Cancellation
           updates['status'] = 'Cancelled';
           // Check if paid, if so refund?
           final paymentStatus = req['payment_status'] ?? 'Unpaid';
           if (paymentStatus == 'Paid') {
             updates['payment_status'] = 'Refunded';
           }
           notificationMessage = "Your cancellation request has been approved. Status is now Cancelled.";
           
           // Also cancel the queue entry if it exists
           await _supabase
               .from('QueueEntry')
               .update({'status': 'Cancelled'})
               .eq('appointment_id', id);

        } else {
           // Reject Cancellation -> Revert to Confirmed
           updates['status'] = 'Confirmed'; 
           notificationMessage = "Your cancellation request was rejected. Your appointment remains Confirmed.";
        }
      } else if (type == 'Reschedule Requested') {
        if (approve && newDateStr != null) {
          updates['status'] = 'Confirmed';
          // Extract date from note
          final regExp = RegExp(r'\[Reschedule Request: (.*?)\]');
          final match = regExp.firstMatch(newDateStr);
          if (match != null) {
             // Parse the string and ensure it is converted to UTC string for DB
             // This handles both old local-string requests and new UTC-string requests correctly
             updates['appointment_datetime'] = DateTime.parse(match.group(1)!).toUtc().toIso8601String();
             
             // Format date for notification
             try {
               final dt = DateTime.parse(match.group(1)!).toLocal();
               notificationMessage = "Your reschedule request has been approved. New time: ${dt.day}/${dt.month} at ${dt.hour}:${dt.minute.toString().padLeft(2,'0')}";
             } catch (_) {
               notificationMessage = "Your reschedule request has been approved.";
             }
          }
        } else {
          // Reject -> Revert to Confirmed
          updates['status'] = 'Confirmed';
          notificationMessage = "Your reschedule request was rejected. Your appointment remains at the original time.";
        }
      }

      // 1. Update Appointment
      await _supabase.from('Appointment').update(updates).eq('appointment_id', id);

      // 2. Send Notification
      if (patientId != null && notificationMessage.isNotEmpty) {
        await _supabase.from('Notification').insert({
          'recipient_id': patientId,
          'message_content': notificationMessage,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(), // Optional: if DB doesn't auto-set
        });
      }

      // Refresh
      _fetchRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? "Request Approved & Notification Sent" : "Request Rejected & Notification Sent"),
            backgroundColor: approve ? Colors.green : Colors.orange,
          )
        );
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _formatRescheduleNote(String note) {
    final regExp = RegExp(r'\[Reschedule Request: (.*?)\]');
    final match = regExp.firstMatch(note);
    if (match != null) {
      try {
        final dt = DateTime.parse(match.group(1)!).toLocal();
        final dateStr = "${dt.day}/${dt.month}/${dt.year}";
        
        int hour = dt.hour;
        final amPm = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        final timeStr = "$hour:${dt.minute.toString().padLeft(2, '0')} $amPm";
        
        return "Requested New Date: $dateStr at $timeStr";
      } catch (e) {
        return note;
      }
    }
    return note;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Requests"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _requests.isEmpty 
          ? const Center(child: Text("No pending requests"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                final status = req['status'];
                final patientName = req['Patient']?['name'] ?? 'Unknown';
                final serviceName = req['Service']?['service_name'] ?? 'Service';
                final currentDt = DateTime.parse(req['appointment_datetime']).toLocal();
                final notes = req['notes'] ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              status == 'Cancellation Requested' ? "CANCELLATION" : "RESCHEDULE",
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: status == 'Cancellation Requested' ? Colors.red : Colors.orange
                              ),
                            ),
                            Text(
                              "${currentDt.day}/${currentDt.month} ${currentDt.hour}:${currentDt.minute.toString().padLeft(2,'0')}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text("$patientName - $serviceName", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (status == 'Reschedule Requested') ...[
                           const SizedBox(height: 8),
                           Container(
                             padding: const EdgeInsets.all(8),
                             width: double.infinity,
                             color: Colors.orange[50],
                             child: Text(
                               _formatRescheduleNote(notes), 
                               style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.deepOrange)
                             ),
                           )
                        ],
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => _processRequest(req['appointment_id'], status, false),
                              child: const Text("Reject"),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => _processRequest(req['appointment_id'], status, true, newDateStr: notes),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              child: const Text("Approve"),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
