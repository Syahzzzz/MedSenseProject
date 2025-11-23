import 'package:flutter/material.dart';

class ServicesView extends StatefulWidget {
  const ServicesView({super.key});

  @override
  State<ServicesView> createState() => _ServicesViewState();
}

class _ServicesViewState extends State<ServicesView> {
  // Selected category state
  String _selectedCategory = 'Braces';

  // Categories
  final List<String> _categories = ['Braces', 'Scaling', 'Whitening', 'Retainers'];

  // Mock Data
  final Map<String, List<Map<String, String>>> _servicesData = {
    'Braces': [
      {
        'title': 'Metal Conventional (Student Jimat Plan)',
        'duration': 'Est. 24-36 month',
        'price': 'From RM150/month',
      },
      {
        'title': 'Metal Conventional (with Deposit)',
        'duration': 'Est. 24-36 month',
        'price': 'From RM150/month',
      },
      {
        'title': 'Metal Conventional (Zero Deposit)',
        'duration': 'Est. 24-36 month',
        'price': 'From RM175/month',
      },
      {
        'title': 'Ceramic Conventional (with Deposit)',
        'duration': 'Est. 24-36 month',
        'price': 'From RM175/month',
      },
      {
        'title': 'Ceramic Conventional (Zero Deposit)',
        'duration': 'Est. 24-36 month',
        'price': 'From RM200/month',
      },
    ],
    'Scaling': [
      {
        'title': 'Basic Scaling & Polishing',
        'duration': 'Est. 30-45 mins',
        'price': 'From RM100',
      },
      {
        'title': 'Deep Cleaning (Gum Treatment)',
        'duration': 'Est. 60 mins',
        'price': 'From RM250',
      },
    ],
    'Whitening': [
      {
        'title': 'Home Whitening Kit',
        'duration': 'Take home kit',
        'price': 'From RM400',
      },
      {
        'title': 'Zoom Teeth Whitening',
        'duration': 'Est. 60 mins',
        'price': 'From RM900',
      },
    ],
    'Retainers': [
      {
        'title': 'Clear Retainers (Pair)',
        'duration': 'Production: 1 week',
        'price': 'From RM400',
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    // Colors
    final Color primaryYellow = const Color(0xFFFBC02D);
    final Color chipColor = const Color(0xFFFFF59D); // Light yellow for tabs

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.reply, size: 32, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Services",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // --- Categories Tabs ---
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
                        category,
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

            // --- Service List ---
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
                            
                            // Plus Button
                            Container(
                              width: 35,
                              height: 35,
                              decoration: BoxDecoration(
                                color: primaryYellow,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.add, size: 20, color: Colors.black),
                                onPressed: () {
                                  // Logic to add service or book
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Selected: ${service['title']}")),
                                  );
                                },
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Divider Line
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