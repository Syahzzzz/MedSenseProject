import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reschedule_view.dart';

class AppointmentReceiptView extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const AppointmentReceiptView({super.key, required this.appointment});

  @override
  State<AppointmentReceiptView> createState() => _AppointmentReceiptViewState();
}

class _AppointmentReceiptViewState extends State<AppointmentReceiptView> {
  bool _isProcessing = false;

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final List<String> months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      
      final String day = date.day.toString().padLeft(2, '0');
      final String month = months[date.month - 1];
      final String year = date.year.toString();
      
      int hour = date.hour;
      final String amPm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final String hourStr = hour.toString().padLeft(2, '0');
      final String minute = date.minute.toString().padLeft(2, '0');

      return '$day $month $year, $hourStr:$minute $amPm';
    } catch (e) {
      return dateStr;
    }
  }

  double _parsePrice(String priceStr) {
    try {
      return double.parse(priceStr.replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (e) {
      return 0.0;
    }
  }

  // Helper to parse the description from DB into a breakdown list
  List<Map<String, String>> _getBreakdown(String serviceTitle, String price) {
    List<Map<String, String>> items = [];
    double total = _parsePrice(price);
    
    if (serviceTitle.contains("Scaling")) {
      double consult = 50;
      double procedure = total - consult;
      if (procedure < 0) { consult = 0; procedure = total; }
      
      items = [
        {'item': 'Consultation & Diagnosis', 'price': 'RM ${consult.toStringAsFixed(0)}'},
        {'item': 'Procedure Fee', 'price': 'RM ${procedure.toStringAsFixed(0)}'},
      ];
    } else if (serviceTitle.contains("Braces") || serviceTitle.contains("Metal") || serviceTitle.contains("Ceramic")) {
      double consult = 200;
      double procedure = total - consult;
      if (procedure < 0) { consult = 0; procedure = total; }
      
      items = [
        {'item': 'Consultation & X-ray', 'price': 'RM ${consult.toStringAsFixed(0)}'},
        {'item': 'Braces Deposit/Fee', 'price': 'RM ${procedure.toStringAsFixed(0)}'},
      ];
    } else if (serviceTitle.contains("Whitening")) {
      double assessment = 50;
      double procedure = total - assessment;
      if (procedure < 0) { assessment = 0; procedure = total; }
      
      items = [
        {'item': 'Dental Assessment', 'price': 'RM ${assessment.toStringAsFixed(0)}'},
        {'item': 'Whitening Kit/Procedure', 'price': 'RM ${procedure.toStringAsFixed(0)}'},
      ];
    } else {
      double consult = 50;
      double procedure = total - consult;
      if (procedure < 0) { consult = 0; procedure = total; }

      items = [
        {'item': 'Consultation', 'price': 'RM ${consult.toStringAsFixed(0)}'},
        {'item': 'Procedure', 'price': 'RM ${procedure.toStringAsFixed(0)}'},
      ];
    }
    
    return items;
  }

  Future<void> _handleCancellation() async {
    final String currentStatus = widget.appointment['status'] ?? 'Pending';
    final bool isPending = currentStatus.toLowerCase() == 'pending';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPending ? "Cancel Appointment" : "Request Cancellation"),
        content: Text(isPending 
          ? "Are you sure you want to cancel this appointment? This action cannot be undone."
          : "Since this appointment is already confirmed, this will send a request to the clinic staff to cancel. Are you sure?"
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Keep Appointment"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isPending ? "Confirm Cancellation" : "Submit Request", style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        final id = widget.appointment['appointment_id'];
        
        // If Pending -> Cancel Immediately
        // If Confirmed -> Request Cancellation
        final String newStatus = isPending ? 'Cancelled' : 'Cancellation Requested';

        await Supabase.instance.client
            .from('Appointment')
            .update({'status': newStatus})
            .eq('appointment_id', id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isPending 
              ? "Appointment cancelled successfully." 
              : "Cancellation request sent to staff.")
            ),
          );
          Navigator.pop(context, true); // Return true to refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRescheduling() async {
    final String currentStatus = widget.appointment['status'] ?? 'Pending';
    final bool isPending = currentStatus.toLowerCase() == 'pending';

    // 1. Navigate to RescheduleView to pick new time
    final DateTime? newDateTime = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(
        builder: (context) => RescheduleView(appointment: widget.appointment),
      ),
    );

    if (newDateTime == null) return;

    // 2. Confirm
    if (!mounted) return;
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPending ? "Confirm Reschedule" : "Confirm Reschedule Request"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isPending 
              ? "Reschedule appointment to:\n\n${newDateTime.toString().split('.')[0]}?"
              : "Request to move appointment to:\n\n${newDateTime.toString().split('.')[0]}\n\nThis will be sent to staff for approval."
            ),
            const SizedBox(height: 15),
            const Text(
              "Note: Rescheduling only have 1 attempt for every booking.",
              style: TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBC02D), foregroundColor: Colors.black),
            child: Text(isPending ? "Confirm Change" : "Submit Request"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        final id = widget.appointment['appointment_id'];
        
        // Prepare note to track attempt
        final currentNotes = widget.appointment['notes'] ?? '';
        final newNote = "$currentNotes\n[Reschedule Request: ${newDateTime.toUtc().toIso8601String()}]".trim();

        if (isPending) {
           // Immediate Update
           await Supabase.instance.client
            .from('Appointment')
            .update({
              'appointment_datetime': newDateTime.toUtc().toIso8601String(),
              'notes': newNote, // Add note to track attempt
            })
            .eq('appointment_id', id);
        } else {
           // Request Mode
           await Supabase.instance.client
            .from('Appointment')
            .update({
              'status': 'Reschedule Requested',
              'notes': newNote, 
            })
            .eq('appointment_id', id);
        }

        // Cancel any existing Queue Entry for this appointment to prevent stale dashboard state
        await _cancelLinkedQueueEntry(id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isPending 
              ? "Appointment rescheduled successfully." 
              : "Reschedule request sent successfully.")
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _cancelLinkedQueueEntry(dynamic appointmentId) async {
    try {
      await Supabase.instance.client
          .from('QueueEntry')
          .update({'status': 'Cancelled'})
          .eq('appointment_id', appointmentId)
          .neq('status', 'Completed');
    } catch (e) {
      debugPrint("Error cancelling queue: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final apt = widget.appointment;
    final doctor = apt['Doctor'] as Map<String, dynamic>? ?? {};
    final service = apt['Service'] as Map<String, dynamic>? ?? {};
    final patient = apt['Patient'] as Map<String, dynamic>? ?? {}; // Extract Patient Data

    final String serviceName = service['service_name'] ?? 'Service';
    final String doctorName = doctor['name'] ?? 'Unknown Doctor';
    
    // Patient Details
    final String patientName = patient['name'] ?? 'Unknown Patient';
    final String patientId = apt['patient_id']?.toString().substring(0, 8) ?? 'Unknown ID';

    final String dateStr = _formatDate(apt['appointment_datetime']);
    
    String priceDisplay = 'RM ${service['price'] ?? '0'}';
    if (apt['custom_price'] != null) {
       priceDisplay = 'RM ${apt['custom_price']}';
    }

    final String status = apt['status'] ?? 'Pending';
    String paymentStatus = apt['payment_status'] ?? 'Unpaid';
    final String notes = apt['notes'] ?? '';

    // Check if rescheduled before
    final bool hasRescheduled = notes.contains('[Reschedule Request:');

    // Logic for Payment Status Display on Cancellation
    if (status.toLowerCase() == 'cancelled') {
      final ps = paymentStatus.toLowerCase();
      if (ps == 'paid' || ps.contains('deposit') || ps == 'refunded') {
        paymentStatus = 'Refunded';
      } else {
        paymentStatus = 'Cancelled';
      }
    }

    // Calculate Breakdown
    final breakdown = _getBreakdown(serviceName, priceDisplay);
    
    // Calculate Amount Paid
    String amountPaid = "RM 0";
    if (paymentStatus.toLowerCase() == 'paid') {
      amountPaid = priceDisplay;
    } else if (paymentStatus.toLowerCase().contains('deposit')) {
       // Heuristic for deposit if needed, or just say 'Partial'
       amountPaid = "RM ${_parsePrice(priceDisplay) / 2}"; // Example, or just 0
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Appointment Details"),
        backgroundColor: const Color(0xFFFBC02D),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Receipt Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 60,
                              child: Image.asset(
                                'images/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.receipt_long, size: 40, color: Color(0xFFFBC02D)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              serviceName.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              dateStr,
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                                            _buildRow("Appointment ID", "#${apt['appointment_id'].toString().substring(0, 8)}..."),
                                                            _buildRow("Patient Name", patientName),
                                                            _buildRow("Patient ID", patientId),
                                                            _buildRow("Status", status.toUpperCase(), isStatus: true),
                                                            _buildRow("Doctor", doctorName),
                                                            _buildRow("Location", "Rawang Clinic"),                                
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20.0),
                                child: Divider(),
                              ),
                              
                              const Text("Price Breakdown", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 10),
                              ...breakdown.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item['item']!, style: const TextStyle(fontSize: 14)),
                                    Text(item['price']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              )),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20.0),
                                child: Divider(),
                              ),

                              _buildRow("Payment Status", paymentStatus.toUpperCase(), isBold: true),
                              
                              if (notes.isNotEmpty) ...[
                                const SizedBox(height: 15),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Notes:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(notes, style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                              
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[200]!)
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Total Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        Text(priceDisplay, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Divider(),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Amount Paid", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                                        Text(amountPaid, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 15),
                              const Text(
                                "* Cancellation Policy: Cancellations made up to 48 hours before the appointment are free. Cancellations made within 48 hours may incur a 5% processing fee on refunds.",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),

              // Buttons
              if (status.toLowerCase() != 'cancelled' && status.toLowerCase() != 'completed' && status.toLowerCase() != 'expired')
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isProcessing 
                          ? null 
                          : () {
                              if (hasRescheduled) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("No more attempt left"))
                                );
                              } else {
                                _handleRescheduling();
                              }
                            },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasRescheduled ? Colors.grey : const Color(0xFFFBC02D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Request Rescheduling", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : _handleCancellation,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isProcessing 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                          : const Text("Request Cancellation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                )
              else
                 Text(
                   "This appointment is ${status.toLowerCase()}.", 
                   style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)
                 ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isStatus = false, bool isBold = false}) {
    Color textColor = Colors.black87;
    if (isStatus) {
      switch (value.toLowerCase()) {
        case 'confirmed':
          textColor = Colors.green;
        case 'pending':
          textColor = Colors.orange;
        case 'completed':
          textColor = Colors.blue;
        case 'cancelled':
          textColor = Colors.red;
        case 'expired':
          textColor = Colors.grey;
        default:
          textColor = Colors.black87;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(
            value, 
            style: TextStyle(
              color: textColor, 
              fontSize: 14, 
              fontWeight: (isStatus || isBold) ? FontWeight.bold : FontWeight.w500
            )
          ),
        ],
      ),
    );
  }
}
