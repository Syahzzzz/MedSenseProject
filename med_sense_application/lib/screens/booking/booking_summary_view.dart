import 'package:flutter/material.dart';
import 'package:med_sense_application/screens/booking/booking_datetime_view.dart';
import 'package:med_sense_application/screens/patient/dashboard.dart';

class BookingSummaryView extends StatelessWidget {
  final String serviceCategory; 
  final String serviceTitle;    
  final String price;           
  final String duration;        
  final String description; // Used for context or breakdown if present
  final bool isOkuMode;

  const BookingSummaryView({
    super.key,
    required this.serviceCategory,
    required this.serviceTitle,
    required this.price,
    required this.duration,
    required this.description,
    this.isOkuMode = false,
  });

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
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
  List<Map<String, String>> _getBreakdown() {
    List<Map<String, String>> items = [];
    
    // 1. Try to parse explicit lines from DB description if they still exist (for compatibility)
    final lines = description.split('\n');
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

  @override
  Widget build(BuildContext context) {
    if (isOkuMode) {
      return _buildOkuUI(context);
    }

    // Application Theme Yellow
    const Color backgroundColor = Color(0xFFFBC02D); 
    const Color cardColor = Colors.white; 

    final List<Map<String, String>> breakdown = _getBreakdown();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'CONFIRM BOOKING', 
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _handleBack(context),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          serviceCategory, 
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _handleBack(context),
                        child: const Icon(Icons.close, size: 28, color: Colors.black),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  Text(
                    "-$serviceTitle",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  // Price Breakdown List
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: breakdown.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Text(
                                    item['item']!,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.black.withValues(alpha: 0.8),
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    item['price']!,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Bottom Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end, 
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            price,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900, 
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            duration,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(
                        height: 45,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookingDateTimeView(
                                  serviceName: serviceTitle,
                                  servicePrice: price,
                                  description: description,
                                  isOkuMode: isOkuMode,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: backgroundColor, 
                            foregroundColor: Colors.black, 
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            "Confirm",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOkuUI(BuildContext context) {
    // OKU Palette
    const Color primaryColor = Color(0xFF5E35B1); // Purple
    const Color accentColor = Color(0xFFFF8F00); // Amber

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 36, color: Colors.black),
          onPressed: () => _handleBack(context),
        ),
        title: const Text(
          "Review Booking",
          style: TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5FE), // Light Blue
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceCategory,
                      style: const TextStyle(fontSize: 22, color: Colors.black54, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      serviceTitle,
                      style: const TextStyle(fontSize: 28, color: Colors.black, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 20),
                    const Divider(thickness: 2),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Price:", style: TextStyle(fontSize: 20)),
                        Text(price, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primaryColor)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Duration:", style: TextStyle(fontSize: 20)),
                        Text(duration, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingDateTimeView(
                          serviceName: serviceTitle,
                          servicePrice: price,
                          description: description,
                          isOkuMode: true,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "CONFIRM & CONTINUE",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}