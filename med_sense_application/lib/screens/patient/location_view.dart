import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:med_sense_application/utils/translations.dart';

class LocationView extends StatelessWidget {
  final VoidCallback onBack;
  final bool isOkuMode;
  final VoidCallback? onChatStaff;
  final VoidCallback? onChatBot;

  const LocationView({
    super.key,
    required this.onBack,
    this.isOkuMode = false,
    this.onChatStaff,
    this.onChatBot,
  });

  void _handleBack(BuildContext context) {
    onBack();
  }

  // Function to launch Google Maps
  Future<void> _launchMap(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch map';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open maps: $e")),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    // Clinic data with real Google Maps query links
    final List<Map<String, dynamic>> clinics = [
      {
        'name': AppTranslations.get('dental_clinic_rawang'),
        'address': 'No.33, Jalan Desa 1/1, Bandar Country Homes, 48000 Rawang',
        'rating': 4.9,
        'reviews': 967,
        'closing_time': '10:00 pm',
        'image': 'images/clinic_rawang.png',
        // Directs to Q & M Dental Clinic (Rawang)
        'mapUrl':
            'https://www.google.com/maps/search/?api=1&query=Q+%26+M+Dental+Clinic+(Rawang)',
      },
      {
        'name': AppTranslations.get('dental_clinic_selayang'),
        'address': 'No. 6, Jalan SJ 3, Taman Selayang Jaya, 68100 Batu Caves',
        'rating': 4.8,
        'reviews': 520,
        'closing_time': '9:30 pm',
        'image': 'images/clinic_selayang.png',
        // Directs to Qualiteeth Dental Clinic Selayang
        'mapUrl':
            'https://www.google.com/maps/search/?api=1&query=Qualiteeth+Dental+Clinic+Selayang',
      },
      {
        'name': AppTranslations.get('dental_clinic_kl'),
        'address': 'Unit 13, Jalan Tun Sambanthan, Brickfields, 50470 KL',
        'rating': 5.0,
        'reviews': 1200,
        'closing_time': '11:00 pm',
        'image': 'images/clinic_kl.png',
        // Directs to Sentral Dental Clinic (near KL Sentral)
        'mapUrl':
            'https://www.google.com/maps/search/?api=1&query=Sentral+Dental+Clinic+KL+Sentral',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Back Arrow ---
              GestureDetector(
                onTap: () => _handleBack(context),
                child:
                    const Icon(Icons.arrow_back, size: 28, color: Colors.black),
              ),

              const SizedBox(height: 20),

              // --- Header ---
              Text(
                AppTranslations.get('choose_location'),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              // --- Subheader ---
              Text(
                AppTranslations.get('dental_clinic_sub'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "${clinics.length} ${AppTranslations.get('locations_count_suffix')}",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),

              const SizedBox(height: 20),

              // --- Clinic List ---
              Expanded(
                child: ListView.builder(
                  itemCount: clinics.length,
                  itemBuilder: (context, index) {
                    final clinic = clinics[index];
                    return GestureDetector(
                      // Make the entire card clickable
                      onTap: () => _launchMap(context, clinic['mapUrl']),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 25),
                        color: Colors.transparent,
                        // Ensures hit test works on empty space
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- Image Container ---
                            Stack(
                              children: [
                                Container(
                                  height: 180,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.grey.withValues(alpha: 0.2),
                                        spreadRadius: 2,
                                        blurRadius: 5,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.asset(
                                      clinic['image'],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[300],
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.grey,
                                                  size: 40),
                                              const SizedBox(height: 8),
                                              Text(
                                                AppTranslations.get(
                                                    'image_not_found'),
                                                style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // Directions Icon Overlay
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.1),
                                            blurRadius: 4,
                                          )
                                        ]),
                                    child: const Icon(Icons.directions,
                                        color: Color(0xFF1976D2), size: 24),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Title
                            Text(
                              clinic['name'],
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),

                            // Rating
                            Row(
                              children: [
                                Text(
                                  "${clinic['rating']} ",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                const Icon(Icons.star,
                                    size: 14, color: Colors.black),
                                const Icon(Icons.star,
                                    size: 14, color: Colors.black),
                                const Icon(Icons.star,
                                    size: 14, color: Colors.black),
                                const Icon(Icons.star,
                                    size: 14, color: Colors.black),
                                const Icon(Icons.star,
                                    size: 14, color: Colors.black),
                                Text(
                                  " (${clinic['reviews']})",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Address
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    clinic['address'],
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Open Status
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black),
                                children: [
                                  TextSpan(
                                    text: AppTranslations.get('open'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text:
                                        "${AppTranslations.get('until')} ${clinic['closing_time']}",
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (isOkuMode) ...[
                const SizedBox(height: 10),
                // Chat buttons removed per request
              ],
            ],
          ),
        ),
      ),
    );
  }
}