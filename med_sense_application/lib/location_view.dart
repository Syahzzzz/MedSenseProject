import 'package:flutter/material.dart';

class LocationView extends StatelessWidget {
  final VoidCallback onBack;

  const LocationView({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    // Mock Data for locations with IMAGE PATHS
    final List<Map<String, dynamic>> clinics = [
      {
        'name': 'Dental Clinic Rawang',
        'address': 'Reef 2, Rawang',
        'rating': 4.9,
        'reviews': 967,
        'closing_time': '10:00 pm',
        'image': 'images/clinic_rawang.png', // Ensure this file exists
      },
      {
        'name': 'Dental Clinic Selayang',
        'address': 'Emerald Avenue, Selayang',
        'rating': 4.8,
        'reviews': 520,
        'closing_time': '9:30 pm',
        'image': 'images/clinic_selayang.png', // Ensure this file exists
      },
      {
        'name': 'Dental Clinic KL Sentral',
        'address': 'Nu Sentral, KL',
        'rating': 5.0,
        'reviews': 1200,
        'closing_time': '11:00 pm',
        'image': 'images/clinic_kl.png', // Ensure this file exists
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
            const Text(
              "Choose a location",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 20),

            // --- Subheader ---
            const Text(
              "Dental Clinic",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "${clinics.length} locations",
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
                                        "Image not found",
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
                            const Text(
                              "4.9 ",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                              const TextSpan(
                                text: "Open ",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: "until ${clinic['closing_time']}",
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