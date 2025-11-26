import 'package:flutter/material.dart';
import 'booking_datetime_view.dart';
import 'dashboard.dart';

class BookingSummaryView extends StatelessWidget {
  final String serviceCategory; // e.g., "Scaling"
  final String serviceTitle;    // e.g., "Basic Scaling & Polishing"
  final String price;           // e.g., "From RM100"
  final String duration;        // e.g., "Est. 30-45 mins"

  const BookingSummaryView({
    super.key,
    required this.serviceCategory,
    required this.serviceTitle,
    required this.price,
    required this.duration,
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

  @override
  Widget build(BuildContext context) {
    // Matches the dark background in the image
    const Color backgroundColor = Color(0xFF1E1E1E); 
    // Matches the pale yellow card
    const Color cardYellow = Color(0xFFFFF9C4); 

    final List<Map<String, String>> breakdown = _getBreakdown(serviceCategory);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        // Lowercase title as per image
        title: const Text('CONFIRM BOOKING', style: TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true, // Centered title
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _handleBack(context),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20), // Spacing below app bar
          
          // The Main Yellow Card
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
                  // Header: Title and Close Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          serviceCategory, // e.g. "Scaling"
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

                  // Subtitle (e.g. "-Basic Scaling & Polishing")
                  Text(
                    "-$serviceTitle",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900, // Extra bold
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
                                // Item Name
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
                                // Price
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    item['price']!,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold, // Bold price
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
                    crossAxisAlignment: CrossAxisAlignment.end, // Align bottom
                    children: [
                      // Price & Duration
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            price, // e.g. "From RM100"
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900, // Extra Bold
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            duration, // e.g. "Est. 30-45 mins"
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      
                      // Confirm Button
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
                            backgroundColor: Colors.white, // White button
                            foregroundColor: Colors.black, // Black text
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

  // Dynamic breakdown data based on category
  List<Map<String, String>> _getBreakdown(String category) {
    // Scaling logic (Matches your image)
    if (category.contains("Scaling")) {
      return [
        {'item': 'Consultation & Diagnosis', 'price': 'Rm50'},
        {'item': 'Procedure Fee', 'price': 'Rm100 - Rm300'},
        {'item': 'Medication (if applicable)', 'price': 'Rm30'},
        {'item': 'Follow-up appointment', 'price': 'Free'},
      ];
    }
    // Braces logic
    if (category.contains("Braces")) {
      return [
        {'item': 'Braces consultation\nXray\nMoulding', 'price': 'Rm200'},
        {'item': 'Scaling & polishing\nUpper braces', 'price': 'Rm499\n(Deposit)'},
        {'item': 'Lower braces\nMonthly payment', 'price': 'Rm150'},
        {'item': 'Extraction/filling (if needed)', 'price': 'Rm120'},
        {'item': 'Braces removal and retainer', 'price': 'Rm700'},
        {'item': 'Bond bracket (per bracket)', 'price': 'Rm60'},
      ];
    }
    // Whitening logic
    if (category.contains("Whitening")) {
      return [
        {'item': 'Dental Assessment', 'price': 'Rm50'},
        {'item': 'Whitening Procedure', 'price': 'Rm800'},
        {'item': 'Take-home Kit', 'price': 'Rm150'},
        {'item': 'Desensitizing Gel', 'price': 'Free'},
      ];
    }
    // Default fallback
    return [
      {'item': 'Consultation', 'price': 'Rm50'},
      {'item': 'Procedure', 'price': 'TBD'},
    ];
  }
}