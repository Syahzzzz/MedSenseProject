import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; 
import 'location_view.dart'; 
import 'services_view.dart'; 
import 'profile_view.dart'; 
import 'translations.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- State & Dependencies ---
  final _supabase = Supabase.instance.client;
  String _userName = "User"; 
  int _selectedIndex = 0; 
  String _selectedServiceCategory = 'Braces';

  // --- Data Constants ---
  final List<String> _serviceCategories = ['Braces', 'Scaling', 'Whitening', 'Retainers'];

  final Map<String, List<Map<String, String>>> _servicesData = {
    'Braces': [
      {'title': 'Metal Conventional', 'duration': 'Est. 24-36 month', 'price': 'From RM150/month'},
      {'title': 'Metal Conventional (Deposit)', 'duration': 'Est. 24-36 month', 'price': 'From RM150/month'},
      {'title': 'Ceramic Conventional', 'duration': 'Est. 24-36 month', 'price': 'From RM175/month'},
    ],
    'Scaling': [
      {'title': 'Basic Scaling', 'duration': 'Est. 30-45 mins', 'price': 'From RM100'},
      {'title': 'Deep Cleaning', 'duration': 'Est. 60 mins', 'price': 'From RM250'},
    ],
    'Whitening': [
      {'title': 'Home Kit', 'duration': 'Take home kit', 'price': 'From RM400'},
      {'title': 'Zoom Whitening', 'duration': 'Est. 60 mins', 'price': 'From RM900'},
    ],
    'Retainers': [
      {'title': 'Clear Pair', 'duration': 'Production: 1 week', 'price': 'From RM400'},
    ],
  };

  final List<Map<String, String>> _doctors = [
    {'name': 'Dr. Sarah Smith', 'specialization': 'Dentist - Orthodontist', 'image': 'images/sarah.png'},
    {'name': 'Dr. John Doe', 'specialization': 'Dentist - Surgeon', 'image': 'images/john.png'},
  ];

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // --- Logic ---
  void _loadUserProfile() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() => _userName = user.userMetadata?['full_name'] ?? "User");
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (_) => const MyHomePage()), 
        (r) => false
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // --- Main Build ---
  @override
  Widget build(BuildContext context) {
    final Color navBarColor = const Color(0xFFFFF9C4);

    return Scaffold(
      backgroundColor: Colors.white,
      
      // Animated Page Transition
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _getBody(),
      ),

      // Bottom Navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBarColor, 
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1), 
              blurRadius: 10
            )
          ]
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent, 
          elevation: 0, 
          type: BottomNavigationBarType.fixed, 
          selectedItemColor: Colors.black,
          currentIndex: _selectedIndex, 
          onTap: _onItemTapped,
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), label: AppTranslations.get('home')),
            BottomNavigationBarItem(icon: const Icon(Icons.location_on_outlined), label: AppTranslations.get('location')),
            BottomNavigationBarItem(icon: const Icon(Icons.calendar_today_outlined), label: AppTranslations.get('booking')),
            BottomNavigationBarItem(icon: const Icon(Icons.person_outline), label: AppTranslations.get('profile')),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _getBody() {
    if (_selectedIndex == 0) return _buildHome();
    if (_selectedIndex == 1) return LocationView(onBack: () => setState(() => _selectedIndex = 0));
    if (_selectedIndex == 3) return const ProfileView();
    return const Center(child: Text("Coming Soon"));
  }

  // The Main Dashboard Content
  Widget _buildHome() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            
            _buildGreeting(),
            const SizedBox(height: 15),
            
            _buildAppointmentBanner(),
            const SizedBox(height: 30),
            
            _buildServicesSection(),
            const SizedBox(height: 20),
            
            _buildServicesList(),
            const SizedBox(height: 30),
            
            _buildDoctorsSection(),
          ],
        ),
      ),
    ); 
  }

  // 1. Top Header
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back), 
          onPressed: _signOut
        ),
        const CircleAvatar(
          backgroundColor: Color(0xFFFBC02D), 
          child: Icon(Icons.person, color: Colors.white)
        ),
      ],
    );
  }

  // 2. Greeting Text
  Widget _buildGreeting() {
    return Align(
      alignment: Alignment.centerLeft, 
      child: Text(
        "${AppTranslations.get('hello')} $_userName", 
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
      )
    );
  }

  // 3. Upcoming Appointment Banner
  Widget _buildAppointmentBanner() {
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  Text(AppTranslations.get('Scaling'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(AppTranslations.get('dental_clinic_rawang'), style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), 
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA000), 
                  borderRadius: BorderRadius.circular(10)
                ), 
                child: Text(
                  AppTranslations.get('upcoming'), 
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                )
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
            child: const Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text("24 Nov 2025", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(width: 15), 
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text("10:00 AM", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          const SizedBox(height: 15),
          const Divider(height: 1, thickness: 0.5), 
          const SizedBox(height: 15),

          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[200],
                backgroundImage: const AssetImage('images/sarah.png'), 
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Dr. Sarah Smith",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    AppTranslations.get('dentist'), 
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      )
    );
  }

  // 4. Services Header & Categories
  Widget _buildServicesSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Text(AppTranslations.get('services'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesView())), 
              child: Text(AppTranslations.get('view_all'), style: const TextStyle(fontWeight: FontWeight.bold))
            ),
          ],
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal, 
          child: Row(
            children: _serviceCategories.map((cat) => 
              GestureDetector(
                onTap: () => setState(() => _selectedServiceCategory = cat), 
                child: Container(
                  margin: const EdgeInsets.only(right: 10), 
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
                  decoration: BoxDecoration(
                    color: _selectedServiceCategory == cat ? const Color(0xFFFBC02D) : const Color(0xFFFFF59D), 
                    borderRadius: BorderRadius.circular(20)
                  ), 
                  child: Text(AppTranslations.get(cat), style: const TextStyle(fontWeight: FontWeight.bold))
                )
              )
            ).toList()
          )
        ),
      ],
    );
  }

  // 5. Dynamic Service List (UPDATED: Removed Plus Button, Added Details)
  Widget _buildServicesList() {
    final currentServices = _servicesData[_selectedServiceCategory] ?? [];
    return Column(
      children: currentServices.map((s) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2))
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s['title']!, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
            ), 
            const SizedBox(height: 4),
            Text(
              "- ${s['duration']!}", 
              style: TextStyle(color: Colors.grey[800], fontSize: 13)
            ),
            const SizedBox(height: 8),
            Text(
              s['price']!, 
              style: TextStyle(color: Colors.grey[600], fontSize: 13)
            ),
          ],
        ),
      )).toList()
    );
  }

  // 6. Top Doctors List
  Widget _buildDoctorsSection() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft, 
          child: Text(AppTranslations.get('top_doctor'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
        ),
        const SizedBox(height: 15),
        Column(
          children: _doctors.map((d) => Container(
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
                        d['image']!,
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
                          d['name']!,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          d['specialization']!,
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
          )).toList()
        ),
      ],
    );
  }
}