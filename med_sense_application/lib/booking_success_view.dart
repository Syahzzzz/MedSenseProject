import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'translations.dart';

class BookingSuccessView extends StatelessWidget {
  const BookingSuccessView({super.key});

  // Color Constants matching the image
  final Color _yellowColor = const Color(0xFFFBC02D);
  final Color _checkIconColor = const Color(0xFFFFB300);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _yellowColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const DashboardPage()),
                        (route) => false,
                      );
                    },
                    child: const Icon(Icons.arrow_back, color: Colors.black54, size: 28),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          AppTranslations.get('booking_successful_title'), // "Booking successfully"
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900, // Very bold
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppTranslations.get('booking_successful_subtitle'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom White Card
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
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon + Text Block
                    Column(
                      children: [
                        // Success Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _checkIconColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Main Success Text
                        Text(
                          AppTranslations.get('your_booking_was_successful'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            height: 1.2,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Description Text
                        Text(
                          AppTranslations.get('booking_success_desc'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                            height: 1.5,
                            fontWeight: FontWeight.w500
                          ),
                        ),
                      ],
                    ),

                    // Bottom Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to Dashboard and remove all previous routes
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const DashboardPage()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _yellowColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          AppTranslations.get('proceed_homepage'),
                          style: const TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold
                          ),
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
    );
  }
}