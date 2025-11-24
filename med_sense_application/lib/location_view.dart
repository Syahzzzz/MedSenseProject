import 'package:flutter/material.dart';
import 'translations.dart';

class LocationView extends StatelessWidget {
  final VoidCallback onBack;

  const LocationView({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    // Dynamic Data with Translations
    final List<Map<String, dynamic>> clinics = [
      {
        'name': AppTranslations.get('dental_clinic_rawang'),
        'address': 'Reef 2, Rawang',
        'rating': 4.9,
        'reviews': 967,
        'closing_time': '10:00 pm',
        'image': 'images/clinic_rawang.png', 
      },
      {
        'name': AppTranslations.get('dental_clinic_selayang'),
        'address': 'Emerald Avenue, Selayang',
        'rating': 4.8,
        'reviews': 520,
        'closing_time': '9:30 pm',
        'image': 'images/clinic_selayang.png', 
      },
      {
        'name': AppTranslations.get('dental_clinic_kl'),
        'address': 'Nu Sentral, KL',
        'rating': 5.0,
        'reviews': 1200,
        'closing_time': '11:00 pm',
        'image': 'images/clinic_kl.png', 
      },
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Back Arrow ---
            GestureDetector(
              onTap: onBack,
              child: const Icon(Icons.reply, size: 28, color: Colors.black54),
            ),
            
            const SizedBox(height: 30),

            // --- Header ---
            Text(
              AppTranslations.get('choose_location'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 20),

            // --- Subheader ---
            Text(
              AppTranslations.get('dental_clinic_sub'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  return Container(
                    margin: const EdgeInsets.only(bottom: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Image Container ---
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.2),
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
                              // Fallback if image is missing
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                                      const SizedBox(height: 8),
                                      Text(
                                        AppTranslations.get('image_not_found'),
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Title
                        Text(
                          clinic['name'],
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        
                        // Rating
                        Row(
                          children: [
                            Text(
                              "${clinic['rating']} ",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Icon(Icons.star, size: 14, color: Colors.black),
                            const Icon(Icons.star, size: 14, color: Colors.black),
                            const Icon(Icons.star, size: 14, color: Colors.black),
                            const Icon(Icons.star, size: 14, color: Colors.black),
                            const Icon(Icons.star, size: 14, color: Colors.black),
                            Text(
                              " (${clinic['reviews']})",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Address
                        Text(
                          clinic['address'],
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(height: 4),

                        // Open Status
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                            children: [
                              TextSpan(
                                text: AppTranslations.get('open'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: "${AppTranslations.get('until')} ${clinic['closing_time']}",
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}