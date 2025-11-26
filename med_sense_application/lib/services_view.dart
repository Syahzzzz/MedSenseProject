import 'package:flutter/material.dart';
import 'translations.dart';
import 'booking_summary_view.dart'; // Import the new summary view
import 'dashboard.dart'; // Import Dashboard for navigation

class ServicesView extends StatefulWidget {
  const ServicesView({super.key});

  @override
  State<ServicesView> createState() => _ServicesViewState();
}

class _ServicesViewState extends State<ServicesView> {
  String _selectedCategory = 'Braces';
  final List<String> _categories = ['Braces', 'Scaling', 'Whitening', 'Retainers'];

  Map<String, List<Map<String, String>>> get _servicesData => {
    'Braces': [
      {
        'title': AppTranslations.get('metal_student'),
        'duration': AppTranslations.get('est_24_36'),
        'price': AppTranslations.get('from_rm150_m'),
      },
      {
        'title': AppTranslations.get('metal_deposit'),
        'duration': AppTranslations.get('est_24_36'),
        'price': AppTranslations.get('from_rm150_m'),
      },
      {
        'title': AppTranslations.get('metal_zero'),
        'duration': AppTranslations.get('est_24_36'),
        'price': AppTranslations.get('from_rm175_m'),
      },
      {
        'title': AppTranslations.get('ceramic_deposit'),
        'duration': AppTranslations.get('est_24_36'),
        'price': AppTranslations.get('from_rm175_m'),
      },
      {
        'title': AppTranslations.get('ceramic_zero'),
        'duration': AppTranslations.get('est_24_36'),
        'price': AppTranslations.get('from_rm200_m'),
      },
    ],
    'Scaling': [
      {
        'title': AppTranslations.get('basic_scaling'),
        'duration': AppTranslations.get('est_30_45'),
        'price': AppTranslations.get('from_rm100'),
      },
      {
        'title': AppTranslations.get('deep_cleaning'),
        'duration': AppTranslations.get('est_60'),
        'price': AppTranslations.get('from_rm250'),
      },
    ],
    'Whitening': [
      {
        'title': AppTranslations.get('home_whitening'),
        'duration': AppTranslations.get('take_home_kit'),
        'price': AppTranslations.get('from_rm400'),
      },
      {
        'title': AppTranslations.get('zoom_whitening'),
        'duration': AppTranslations.get('est_60'),
        'price': AppTranslations.get('from_rm900'),
      },
    ],
    'Retainers': [
      {
        'title': AppTranslations.get('clear_retainers'),
        'duration': AppTranslations.get('production_1_week'),
        'price': AppTranslations.get('from_rm400'),
      },
    ],
  };

  void _handleBack() {
    // Instead of just popping, we explicitly push replacement to Dashboard
    // This ensures we don't accidentally go back to Login if the stack was messy
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardPage()),
      (route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryYellow = const Color(0xFFFBC02D);
    final Color chipColor = const Color(0xFFFFF59D);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _handleBack, // Updated back navigation
                    child: const Icon(Icons.arrow_back, size: 28, color: Colors.black), // Consistent Icon
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppTranslations.get('services_title'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryYellow : chipColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        AppTranslations.get(category),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                itemCount: _servicesData[_selectedCategory]?.length ?? 0,
                itemBuilder: (context, index) {
                  final service = _servicesData[_selectedCategory]![index];
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service['title']!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "- ${service['duration']}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    service['price']!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 10),

                            SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BookingSummaryView(
                                        serviceCategory: AppTranslations.get(_selectedCategory),
                                        serviceTitle: service['title']!,
                                        price: service['price']!,
                                        duration: service['duration']!,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryYellow,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text(
                                  "Book",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.grey, thickness: 0.5),
                    ],
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