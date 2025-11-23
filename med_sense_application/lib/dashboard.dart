import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; 
import 'location_view.dart'; 
import 'services_view.dart'; 

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _supabase = Supabase.instance.client;
  String _userName = "Zhaim"; 
  int _selectedIndex = 0; 
  
  // --- Services Tabs State ---
  String _selectedServiceCategory = 'Braces';
  final List<String> _serviceCategories = ['Braces', 'Scaling', 'Whitening', 'Retainers'];

  // --- Services Data ---
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
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final user = _supabase.auth.currentUser;
    if (user != null && user.userMetadata != null) {
      setState(() {
        _userName = user.userMetadata?['full_name'] ?? "User";
      });
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MyHomePage()),
        (route) => false,
      );
    }
  }

  final List<Map<String, String>> _doctors = [
    {
      'name': 'Dr. Sarah Smith',
      'specialization': 'Dentist - Orthodontist',
      'image': 'images/sarah.png',
    },
    {
      'name': 'Dr. John Doe',
      'specialization': 'Dentist - Surgeon',
      'image': 'images/john.png',
    },
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color lightYellowBg = const Color(0xFFFFF9C4); 

    return Scaffold(
      backgroundColor: Colors.white,
      
      // --- ANIMATED BODY (UPDATED TO NORMAL FADE) ---
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300), // Standard duration
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        // Using simple FadeTransition instead of Slide+Fade
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _getBodyWidget(),
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: lightYellowBg, 
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent, 
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black87,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 28),
              label: 'HOME',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined, size: 28),
              label: 'LOCATION',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined, size: 28),
              label: 'BOOKING',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 28),
              label: 'PROFILE',
            ),
          ],
        ),
      ),
    );
  }

  Widget _getBodyWidget() {
    switch (_selectedIndex) {
      case 0:
        return Container(
          key: const ValueKey<int>(0), 
          child: _buildHomeContent(),
        );
      case 1:
        return LocationView(
          key: const ValueKey<int>(1),
          onBack: () => _onItemTapped(0),
        );
      case 2:
        return Container(
          key: const ValueKey<int>(2),
          child: const Center(child: Text("Booking Page Coming Soon")),
        );
      case 3:
        return Container(
          key: const ValueKey<int>(3),
          child: const Center(child: Text("Profile Page Coming Soon")),
        );
      default:
        return Container(key: const ValueKey<int>(-1));
    }
  }

  Widget _buildHomeContent() {
    final Color primaryYellow = const Color(0xFFFBC02D);
    final Color bannerYellow = const Color(0xFFFFF59D);
    final Color chipColor = const Color(0xFFFFF59D); 

    // Get current services list based on selection
    final currentServices = _servicesData[_selectedServiceCategory] ?? [];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 28, color: Colors.grey),
                  onPressed: _signOut,
                  tooltip: 'Logout',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 28, color: Colors.grey),
                    const SizedBox(width: 15),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: primaryYellow,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 20),

            // --- Greeting ---
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 24, color: Colors.black),
                children: [
                  const TextSpan(text: 'Hello ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: _userName),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // --- Appointment Banner ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Scaling",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                "Dental Clinic Rawang",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA000), 
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "Upcoming",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 15),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          "24 Nov 2025",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          height: 15,
                          width: 1,
                          color: Colors.grey[400],
                          margin: const EdgeInsets.symmetric(horizontal: 15),
                        ),
                        const Icon(Icons.access_time_rounded, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          "10:00 AM",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: const AssetImage('images/sarah.png'),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Dr. Sarah Smith",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Dentist",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- Services Header ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Services",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ServicesView()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: bannerYellow, 
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "View all",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),

            // --- Service Categories (Tabs) ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _serviceCategories.map((category) {
                  final isSelected = _selectedServiceCategory == category;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedServiceCategory = category;
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
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // --- DYNAMIC SERVICES LIST ---
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentServices.length,
              itemBuilder: (context, index) {
                final service = currentServices[index];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "- ${service['duration']}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  service['price']!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Plus Button
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: primaryYellow,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, size: 18, color: Colors.black),
                              onPressed: () {
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
                    const Divider(color: Colors.grey, thickness: 0.2),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            const Text(
              "Top Doctor & Staff",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 15),

            ListView.builder(
              shrinkWrap: true, 
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _doctors.length,
              itemBuilder: (context, index) {
                return _buildDoctorCard(_doctors[index]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, String> doctor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      height: 100, 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.asset(
                  doctor['image']!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.person, color: Colors.grey[400], size: 40);
                  },
                ),
              ),
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 15.0, top: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    doctor['name']!,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    doctor['specialization']!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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