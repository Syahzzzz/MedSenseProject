import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'translations.dart';

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
  String _paymentMethod = 'Credit/debit'; // Default
  // Theme Color
  final Color _primaryYellow = const Color(0xFFFBC02D);

  @override
  void initState() {
    super.initState();
  }

  void _handleConfirm() {
    // Here you would typically save the booking to your database
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppTranslations.get('booking_success')),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardPage()),
      (route) => false,
    );
  }

  // --- Helper to get breakdown items based on service name ---
  List<Map<String, String>> _getBreakdown(String serviceName) {
    // 1. Try to parse explicit lines from description if they exist (backward compatibility)
    List<Map<String, String>> items = [];
    final lines = widget.description.split('\n');
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // If line contains price indicators
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

    if (items.isNotEmpty) {
      return items;
    }

    // 2. Fall back to using the passed 'servicePrice' (which comes from DB) in standard templates
    if (serviceName.contains("Scaling")) {
      return [
        {'item': 'Consultation & Diagnosis', 'price': 'RM 50'},
        {'item': 'Procedure Fee', 'price': widget.servicePrice}, // Use DB price
        {'item': 'Medication (if applicable)', 'price': 'RM 30'},
        {'item': 'Follow-up appointment', 'price': 'Free'},
      ];
    }
    // Braces logic
    if (serviceName.contains("Metal") || serviceName.contains("Ceramic") || serviceName.contains("Braces")) {
      return [
        {'item': 'Braces consultation\nXray\nMoulding', 'price': 'RM 200'},
        {'item': 'Scaling & polishing\nUpper braces', 'price': widget.servicePrice}, // Use DB price
        {'item': 'Lower braces\nMonthly payment', 'price': 'RM 150'},
        {'item': 'Extraction/filling (if needed)', 'price': 'RM 120'},
        {'item': 'Braces removal and retainer', 'price': 'RM 700'},
        {'item': 'Bond bracket (per bracket)', 'price': 'RM 60'},
      ];
    }
    // Whitening logic
    if (serviceName.contains("Whitening")) {
      return [
        {'item': 'Dental Assessment', 'price': 'RM 50'},
        {'item': 'Whitening Procedure', 'price': widget.servicePrice}, // Use DB price
        {'item': 'Take-home Kit', 'price': 'RM 150'},
        {'item': 'Desensitizing Gel', 'price': 'Free'},
      ];
    }
    // Default fallback
    return [
      {'item': 'Consultation', 'price': 'RM 50'},
      {'item': 'Procedure', 'price': widget.servicePrice}, // Use DB price
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
                          
                          _buildPaymentOption(AppTranslations.get('credit_debit')),
                          const SizedBox(height: 12),
                          _buildPaymentOption(AppTranslations.get('online_banking')),
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
                              onPressed: _handleConfirm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFBC02D),
                                foregroundColor: Colors.black,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                              ),
                              child: Text(
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

  Widget _buildPaymentOption(String label) {
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