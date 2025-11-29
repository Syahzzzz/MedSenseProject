import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'translations.dart';
import 'booking_summary_view.dart'; 
import 'dashboard.dart';

class ServicesView extends StatefulWidget {
  const ServicesView({super.key});

  @override
  State<ServicesView> createState() => _ServicesViewState();
}

class _ServicesViewState extends State<ServicesView> {
  String _selectedCategory = 'Braces';
  final List<String> _categories = ['Braces', 'Scaling', 'Whitening', 'Retainers'];
  
  bool _isLoading = true;
  Map<String, List<Map<String, String>>> _servicesData = {};

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoading = true);
    
    try {
      final supabase = Supabase.instance.client;
      
      // Fetch all services from the public."Service" table, including the new 'price' column
      final List<dynamic> response = await supabase
          .from('Service') 
          .select('service_name, description, estimated_duration_minutes, price')
          .order('service_name', ascending: true);

      final Map<String, List<Map<String, String>>> categorizedServices = {
        'Braces': [],
        'Scaling': [],
        'Whitening': [],
        'Retainers': [],
      };

      for (var item in response) {
        final String name = item['service_name'] as String;
        final String rawDescription = item['description'] as String? ?? '';
        final int duration = item['estimated_duration_minutes'] as int? ?? 0;
        final num priceVal = item['price'] as num? ?? 0;
        
        // Format the numeric price from the database
        String priceText = "RM ${priceVal.toStringAsFixed(0)}";
        
        // Use raw description directly
        String descriptionText = rawDescription;

        String category = 'Other';
        if (name.contains('Braces') || name.contains('Invisalign') || name.contains('Retainer Bond')) {
          category = 'Braces';
        } else if (name.contains('Scaling') || name.contains('Polishing') || name.contains('Cleaning') || name.contains('Periodontal')) {
          category = 'Scaling';
        } else if (name.contains('Whitening') || name.contains('Bleaching')) {
          category = 'Whitening';
        } else if (name.contains('Retainer') && !name.contains('Bond')) {
          category = 'Retainers';
        } 
        
        if (categorizedServices.containsKey(category)) {
          categorizedServices[category]!.add({
            'title': name,
            'duration': 'Est. $duration mins',
            'price': priceText,
            'raw_desc': descriptionText,
            'full_desc': rawDescription, // Pass full description for context if needed
          });
        }
      }

      if (mounted) {
        setState(() {
          _servicesData = categorizedServices;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint('Error fetching services: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading services: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleBack() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardPage()),
      (route) => false, 
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
                    onTap: _handleBack,
                    child: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppTranslations.get('services_title'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Category Selector
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

            // Service List
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFBC02D)))
                : _servicesData[_selectedCategory]?.isEmpty ?? true
                    ? Center(child: Text("No services found for $_selectedCategory"))
                    : ListView.builder(
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
                                          const SizedBox(height: 8),
                                          if (service['raw_desc']!.isNotEmpty && service['raw_desc'] != service['title'])
                                             Text(
                                              service['raw_desc']!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                                fontStyle: FontStyle.italic
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Text(
                                            service['price']!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w600
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
                                                description: service['full_desc']!, 
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