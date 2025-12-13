import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'translations.dart';
import 'booking_success_view.dart'; // Import the new success view

class ReviewConfirmView extends StatefulWidget {
  final String clinicNameKey;
  final String clinicAddress;
  final String serviceName;
  final String servicePrice;
  final String description; 
  final DateTime date;
  final String time;
  final String doctorName; 

  const ReviewConfirmView({
    super.key,
    required this.clinicNameKey,
    required this.clinicAddress,
    required this.serviceName,
    required this.servicePrice,
    required this.description, 
    required this.date,
    required this.time,
    required this.doctorName, 
  });

  @override
  State<ReviewConfirmView> createState() => _ReviewConfirmViewState();
}

class _ReviewConfirmViewState extends State<ReviewConfirmView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _paymentMethod = 'Credit/debit'; // Default
  // Theme Color
  final Color _primaryYellow = const Color(0xFFFBC02D);

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleConfirm() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to book.')));
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Get Service ID
      final serviceRes = await _supabase
          .from('Service')
          .select('service_id')
          .eq('service_name', widget.serviceName)
          .maybeSingle();
      
      if (serviceRes == null) throw "Service not found: ${widget.serviceName}";
      final serviceId = serviceRes['service_id'];

      // 2. Get Doctor ID
      final doctorRes = await _supabase
          .from('Doctor')
          .select('doctor_id')
          .eq('name', widget.doctorName)
          .maybeSingle();

      if (doctorRes == null) throw "Doctor not found: ${widget.doctorName}";
      final doctorId = doctorRes['doctor_id'];

      // 3. Combine Date & Time
      final DateTime fullDateTime = _parseDateTime(widget.date, widget.time);

      // 4. Insert Appointment
      await _supabase.from('Appointment').insert({
        'patient_id': user.id,
        'doctor_id': doctorId,
        'service_id': serviceId,
        'appointment_datetime': fullDateTime.toIso8601String(),
        'status': 'Confirmed', 
        'predicted_wait_time_minutes': 0, 
      });

      if (!mounted) return;

      // Navigate to Success View instead of generic Snackbar/Home
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BookingSuccessView()),
      );

    } catch (e) {
      debugPrint('Booking Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DateTime _parseDateTime(DateTime date, String timeStr) {
    try {
      final parts = timeStr.split(' '); 
      final timeParts = parts[0].split(':'); 
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      
      if (parts[1] == 'PM' && hour != 12) hour += 12;
      if (parts[1] == 'AM' && hour == 12) hour = 0;

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      debugPrint("Time parsing error: $e");
      return date;
    }
  }

  // --- Helper to parse "RM 123" to 123.0 ---
  double _parsePrice(String priceStr) {
    try {
      return double.parse(priceStr.replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (e) {
      return 0.0;
    }
  }

  // --- Helper to get breakdown items based on service name ---
  List<Map<String, String>> _getBreakdown(String serviceName) {
    // 1. Try to parse explicit lines from description if they exist (backward compatibility)
    List<Map<String, String>> items = [];
    final lines = widget.description.split('\n');
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      if (line.startsWith('Price:') || line.startsWith('Deposit:') || line.startsWith('Monthly:')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          items.add({
            'item': parts[0].trim(),
            'price': parts[1].trim(),
          });
        }
      }
    }

    if (items.isNotEmpty) return items;

    // 2. Calculation logic based on total price
    double total = _parsePrice(widget.servicePrice);

    if (serviceName.contains("Scaling")) {
      double consult = 50;
      double procedure = total - consult;
      if (procedure < 0) { consult = 0; procedure = total; }
      
      return [
        {'item': 'Consultation & Diagnosis', 'price': 'RM ${consult.toStringAsFixed(0)}'},
        {'item': 'Procedure Fee', 'price': 'RM ${procedure.toStringAsFixed(0)}'},
        {'item': 'Medication (if applicable)', 'price': 'Pay at venue'},
      ];
    }
    
    // Braces logic
    if (serviceName.contains("Metal") || serviceName.contains("Ceramic") || serviceName.contains("Braces")) {
      double consult = 200;
      double deposit = total - consult;
      if (deposit < 0) { consult = 0; deposit = total; }

      return [
        {'item': 'Consultation & X-ray', 'price': 'RM ${consult.toStringAsFixed(0)}'},
        {'item': 'Braces Deposit/Fee', 'price': 'RM ${deposit.toStringAsFixed(0)}'},
        {'item': 'Monthly payment', 'price': 'From RM 150'},
        {'item': 'Retainer (end of treatment)', 'price': 'Pay at venue'},
      ];
    }
    
    // Whitening logic
    if (serviceName.contains("Whitening")) {
      double assessment = 50;
      double procedure = total - assessment;
      if (procedure < 0) { assessment = 0; procedure = total; }
      
      return [
        {'item': 'Dental Assessment', 'price': 'RM ${assessment.toStringAsFixed(0)}'},
        {'item': 'Whitening Procedure', 'price': 'RM ${procedure.toStringAsFixed(0)}'},
        {'item': 'Take-home Kit', 'price': 'Included'},
      ];
    }
    
    // Default fallback
    double consult = 50;
    double procedure = total - consult;
    if (procedure < 0) { consult = 0; procedure = total; }

    return [
      {'item': 'Consultation', 'price': 'RM ${consult.toStringAsFixed(0)}'},
      {'item': 'Procedure', 'price': 'RM ${procedure.toStringAsFixed(0)}'},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final String displayDate = "${widget.date.day}/${widget.date.month}/${widget.date.year}";
    
    // Use the passed service price directly
    final String priceDisplay = widget.servicePrice;

    final List<Map<String, String>> breakdown = _getBreakdown(widget.serviceName);

    return Scaffold(
      backgroundColor: _primaryYellow, // Theme Yellow
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.yellow),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Title Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppTranslations.get('review_confirm'),
                style: const TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),

          // Main Content Card
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Clinic Info
                          Text(
                            AppTranslations.get(widget.clinicNameKey),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Text("4.9 ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Icon(Icons.star, size: 16, color: Colors.black),
                              Icon(Icons.star, size: 16, color: Colors.black),
                              Icon(Icons.star, size: 16, color: Colors.black),
                              Icon(Icons.star, size: 16, color: Colors.black),
                              Icon(Icons.star, size: 16, color: Colors.black),
                              Text(" (967)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.clinicAddress,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 14, color: Colors.black),
                              children: [
                                TextSpan(
                                  text: "${AppTranslations.get('open')} ", 
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: "${AppTranslations.get('until')} 10:00 pm", 
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Date & Time
                          Text(
                            displayDate, 
                            style: const TextStyle(fontSize: 15, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${widget.time} (30 minutes duration)",
                            style: const TextStyle(fontSize: 15, color: Colors.black87),
                          ),

                          const SizedBox(height: 30),

                          // Service Info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.serviceName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${AppTranslations.get('with')} ${widget.doctorName.toUpperCase()}",
                                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                priceDisplay,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          const Divider(thickness: 1),
                          const SizedBox(height: 20),

                          // --- Subtotal Details (Full Breakdown) ---
                          Text(
                            AppTranslations.get('subtotal'), 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 15),
                          
                          // Breakdown List
                          ...breakdown.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Item Name
                                  Expanded(
                                    flex: 6,
                                    child: Text(
                                      item['item']!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  // Price
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      item['price']!,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 15),
                          const Divider(thickness: 1),
                          const SizedBox(height: 20),

                          // Total Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(AppTranslations.get('total'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                              Text(priceDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(AppTranslations.get('pay_now'), style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                              Text(priceDisplay, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(AppTranslations.get('pay_at_venue'), style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                              Text("RM 0", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            ],
                          ),

                          const SizedBox(height: 30),

                          // Payment Method
                          Text(
                            AppTranslations.get('payment_method'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                          const SizedBox(height: 15),
                          
                          _buildPaymentOption(AppTranslations.get('credit_debit'), Icons.credit_card),
                          const SizedBox(height: 12),
                          _buildPaymentOption(AppTranslations.get('online_banking'), Icons.account_balance),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                priceDisplay,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                AppTranslations.get('est_24_36'),
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleConfirm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFBC02D),
                                foregroundColor: Colors.black,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                              ),
                              child: _isLoading 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                : Text(
                                    AppTranslations.get('confirm'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String label, IconData icon) {
    final bool isSelected = _paymentMethod == label;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.transparent, // Hit test area
        child: Row(
          children: [
            Container(
              width: 50,
              height: 35,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: Colors.black54, size: 20),
            ),
            const SizedBox(width: 15),
            Text(label, style: const TextStyle(fontSize: 15, color: Colors.black87)),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.black, size: 24),
          ],
        ),
      ),
    );
  }
}