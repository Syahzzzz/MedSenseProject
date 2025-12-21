import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'translations.dart';
import 'appointment_receipt_view.dart';

class BookingHistoryView extends StatefulWidget {
  const BookingHistoryView({super.key});

  @override
  State<BookingHistoryView> createState() => _BookingHistoryViewState();
}

class _BookingHistoryViewState extends State<BookingHistoryView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _clearNewBookingFlag();
    _fetchBookings();
  }

  Future<void> _clearNewBookingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_new_booking', false);
  }

  Future<void> _fetchBookings() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _supabase
          .from('Appointment')
          .select('*, Service(service_name, price), Doctor(name, specialization), Patient(name)')
          .eq('patient_id', user.id)
          .order('appointment_datetime', ascending: false);

      if (mounted) {
        setState(() {
          _bookings = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(AppTranslations.get('booking_history')), 
        backgroundColor: const Color(0xFFFBC02D),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFBC02D)))
          : _bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No past bookings found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : _buildGroupedList(),
    );
  }

  Widget _buildGroupedList() {
    // Group bookings by Service Name
    final Map<String, List<Map<String, dynamic>>> groupedBookings = {};
    
    for (var booking in _bookings) {
      final service = booking['Service'] as Map<String, dynamic>? ?? {};
      final serviceName = service['service_name'] as String? ?? 'Other Services';
      
      if (!groupedBookings.containsKey(serviceName)) {
        groupedBookings[serviceName] = [];
      }
      groupedBookings[serviceName]!.add(booking);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedBookings.length,
      itemBuilder: (context, index) {
        final serviceName = groupedBookings.keys.elementAt(index);
        final serviceBookings = groupedBookings[serviceName]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: index == 0, // Open the first one by default
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                serviceName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text(
                "${serviceBookings.length} Appointment${serviceBookings.length > 1 ? 's' : ''}",
                style: TextStyle(color: Colors.grey[600]),
              ),
              children: serviceBookings.map((booking) => _buildBookingItem(booking)).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookingItem(Map<String, dynamic> booking) {
    final doctor = booking['Doctor'] as Map<String, dynamic>? ?? {};
    final service = booking['Service'] as Map<String, dynamic>? ?? {};
    String status = booking['status'] as String? ?? 'Unknown';
    String paymentStatus = booking['payment_status'] as String? ?? 'Unpaid'; // Default to Unpaid
    String notes = booking['notes'] as String? ?? ''; // Get notes
    String paymentMethod = booking['payment_method'] as String? ?? '-';
    
    // Price Logic: Use custom_price if available, else service price
    String priceDisplay = 'RM ${service['price'] ?? '0'}';
    if (booking['custom_price'] != null) {
       priceDisplay = 'RM ${booking['custom_price']}';
    }

    // Check for expiration
    try {
      final appointmentDateTime = DateTime.parse(booking['appointment_datetime']).toLocal();
      if (appointmentDateTime.isBefore(DateTime.now()) && 
          (status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'pending')) {
        status = 'Expired';
      }
    } catch (e) {
      // Keep original
    }

    String displayStatus = status;
    if (status.toLowerCase() == 'pending') displayStatus = 'Pending Review';

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'confirmed': statusColor = Colors.green;
      case 'pending': statusColor = Colors.orange;
      case 'completed': statusColor = Colors.blue;
      case 'cancelled': statusColor = Colors.red;
      case 'refunded': statusColor = Colors.purple; // Add refunded visual if needed
      case 'expired': statusColor = Colors.grey.shade700;
      default: statusColor = Colors.grey;
    }
    
    // Payment Status Color
    Color paymentColor;
    if (paymentStatus == 'Paid') {
      paymentColor = Colors.green;
    } else if (paymentStatus == 'Refunded') {
      paymentColor = Colors.purple;
    } else {
      paymentColor = Colors.red;
    }

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentReceiptView(appointment: booking),
          ),
        );
        // Refresh list when returning (in case status changed)
        _fetchBookings();
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _formatDate(booking['appointment_datetime']),
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  displayStatus.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (doctor.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  doctor['name'] ?? 'Unknown Doctor',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
           const SizedBox(height: 4),
           Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Row(
                   children: [
                     const Icon(Icons.payments_outlined, size: 16, color: Colors.grey),
                     const SizedBox(width: 8),
                     Text(
                      priceDisplay,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                     ),
                   ],
                 ),
                 // Payment Status Indicator
                 Text(
                   paymentStatus.toUpperCase(),
                   style: TextStyle(
                     color: paymentColor,
                     fontWeight: FontWeight.bold,
                     fontSize: 12,
                   ),
                 ),
              ],
           ),
           const SizedBox(height: 4),
           Row(
             children: [
               const Icon(Icons.payment, size: 16, color: Colors.grey),
               const SizedBox(width: 8),
               Expanded(
                 child: Text(
                   paymentMethod,
                   style: TextStyle(color: Colors.grey[700], fontSize: 13),
                   overflow: TextOverflow.ellipsis,
                 ),
               ),
             ],
           ),
           if (notes.isNotEmpty) ...[
             const SizedBox(height: 8),
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: Colors.yellow[50],
                 borderRadius: BorderRadius.circular(8),
                 border: Border.all(color: Colors.yellow[200]!),
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     "Note from clinic:", 
                     style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[800])
                   ),
                   const SizedBox(height: 2),
                   Text(
                     notes,
                     style: TextStyle(fontSize: 12, color: Colors.grey[800], fontStyle: FontStyle.italic),
                   ),
                 ],
               ),
             ),
           ],
           // Timeline View
           _buildTimelineWidget(booking),
        ],
      ),
    ));
  }

  Widget _buildTimelineWidget(Map<String, dynamic> currentApt) {
    // 1. Find Ancestors within the loaded _bookings list
    List<Map<String, dynamic>> chain = [];
    String? prevId = currentApt['previous_appointment_id'];
    
    // Trace back
    int depth = 0;
    while (prevId != null && depth < 10) {
      try {
        final ancestor = _bookings.firstWhere((a) => a['appointment_id'] == prevId);
        chain.insert(0, ancestor); // Add to beginning (oldest first)
        prevId = ancestor['previous_appointment_id'];
        depth++;
      } catch (e) {
        break; // Ancestor not found in loaded list
      }
    }

    if (chain.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          "Follow-up History",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        ...chain.asMap().entries.map((entry) {
          final _ = entry.key;
          final item = entry.value;
          
          final dt = DateTime.parse(item['appointment_datetime']).toLocal();
          final dateStr = "${dt.day}/${dt.month}";
          final serviceName = item['Service']?['service_name'] ?? 'Service';

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 1,
                        color: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      "$dateStr: $serviceName",
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        // Connection to current
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
             Container(
               width: 8,
               height: 8,
               decoration: const BoxDecoration(
                 shape: BoxShape.circle,
                 color: Color(0xFFFBC02D), 
               ),
             ),
             const SizedBox(width: 8),
             const Text("Current", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
          ],
        )
      ],
    );
  }
}
