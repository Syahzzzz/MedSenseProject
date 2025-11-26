import 'package:flutter/material.dart';
import 'booking_datetime_view.dart';
import 'dashboard.dart';

class BookingSummaryView extends StatelessWidget {
  final String serviceCategory; 
  final String serviceTitle;    
  final String price;           
  final String duration;        
  final String description; // Added to parse details from

  const BookingSummaryView({
    super.key,
    required this.serviceCategory,
    required this.serviceTitle,
    required this.price,
    required this.duration,
    required this.description, // Receive full description
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

  // Helper to parse the description from DB into a breakdown list
  List<Map<String, String>> _getBreakdown() {
    // If the description has explicit price lines (e.g. "Deposit: RM 500"), use them.
    // Otherwise, use standard defaults based on category/name.
    
    List<Map<String, String>> items = [];
    
    // 1. Try to parse explicit lines from DB description
    final lines = description.split('\n');
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

    // 2. If no specific price lines found, fall back to generic breakdown logic
    if (items.isEmpty) {
      if (serviceTitle.contains("Scaling")) {
        items = [
          {'item': 'Consultation & Diagnosis', 'price': 'RM 50'},
          {'item': 'Procedure Fee', 'price': price}, // Use the passed total price
        ];
      } else if (serviceTitle.contains("Braces")) {
        items = [
          {'item': 'Consultation & X-ray', 'price': 'RM 200'},
          {'item': 'Braces Deposit/Fee', 'price': price},
        ];
      } else if (serviceTitle.contains("Whitening")) {
        items = [
          {'item': 'Dental Assessment', 'price': 'RM 50'},
          {'item': 'Whitening Kit/Procedure', 'price': price},
        ];
      } else {
        items = [
          {'item': 'Consultation', 'price': 'RM 50'},
          {'item': 'Procedure', 'price': price},
        ];
      }
    }
    
    return items;
  }

  @override
  Widget build(BuildContext context) {
    // Application Theme Yellow
    const Color backgroundColor = Color(0xFFFBC02D); 
    const Color cardYellow = Color(0xFFFFF9C4); 

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
                color: cardYellow,
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
}