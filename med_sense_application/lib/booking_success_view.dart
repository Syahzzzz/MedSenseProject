import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'translations.dart';

class BookingSuccessView extends StatelessWidget {
  final Map<String, dynamic>? appointmentDetails;

  const BookingSuccessView({
    super.key, 
    this.appointmentDetails,
  });

  // Color Constants matching the image
  final Color _yellowColor = const Color(0xFFFBC02D);
  final Color _checkIconColor = Colors.green;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _yellowColor,
      body: SafeArea(
        bottom: false, // Extend white background to bottom edge
        child: Column(
          children: [
            // Top Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const DashboardPage()),
                      (route) => false,
                    );
                  },
                  child: const Icon(Icons.close, color: Colors.black54, size: 28),
                ),
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
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                    child: Column(
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
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                height: 1.2,
                              ),
                            ),
                            
                            const SizedBox(height: 15),
                            
                            // Description Text
                            Text(
                              AppTranslations.get('booking_success_desc'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                height: 1.5,
                                fontWeight: FontWeight.w500
                              ),
                            ),
                          ],
                        ),

                        // Quick Receipt Card
                        if (appointmentDetails != null) ...[
                          const SizedBox(height: 30),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  appointmentDetails!['service_name']?.toUpperCase() ?? 'SERVICE',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 16, 
                                    letterSpacing: 1
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 15),
                                const Divider(),
                                const SizedBox(height: 15),
                                _buildReceiptRow(Icons.calendar_today, "${appointmentDetails!['date']} • ${appointmentDetails!['time']}"),
                                _buildReceiptRow(Icons.person, appointmentDetails!['doctor_name'] ?? ''),
                                _buildReceiptRow(Icons.location_on, appointmentDetails!['clinic_name'] ?? ''),
                                if (appointmentDetails!['appointment_id'] != null)
                                   _buildReceiptRow(Icons.confirmation_number, "ID: #${appointmentDetails!['appointment_id'].toString().substring(0, 8)}"),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 40),

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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text, 
              style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)
            ),
          ),
        ],
      ),
    );
  }
}
