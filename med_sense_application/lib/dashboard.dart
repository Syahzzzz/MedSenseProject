import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
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
  String? _avatarUrl; 
  int _selectedIndex = 0; 
  String _selectedServiceCategory = 'Braces';

  // Dynamic Services Data
  bool _isServicesLoading = true;
  Map<String, List<Map<String, String>>> _servicesData = {};

  // --- Data Constants ---
  final List<String> _serviceCategories = ['Braces', 'Scaling', 'Whitening', 'Retainers'];

  List<Map<String, String>> get _doctors => [
    {'name': 'Dr. Sarah Smith', 'specialization': AppTranslations.get('dentist_ortho'), 'image': 'images/sarah.png'},
    {'name': 'Dr. John Doe', 'specialization': AppTranslations.get('dentist_surgeon'), 'image': 'images/john.png'},
  ];

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _fetchServices(); // Load services on init
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestNotificationPermission();
    });
  }

  // --- Fetch Services from Supabase ---
  Future<void> _fetchServices() async {
    if (!mounted) return;
    setState(() => _isServicesLoading = true);
    
    try {
      // Fetch services from DB
      final List<dynamic> response = await _supabase
          .from('Service') 
          .select('service_name, description, estimated_duration_minutes')
          .order('service_name', ascending: true);

      final Map<String, List<Map<String, String>>> categorized = {
        'Braces': [],
        'Scaling': [],
        'Whitening': [],
        'Retainers': [],
      };

      for (var item in response) {
        final String name = item['service_name'] as String;
        final String rawDescription = item['description'] as String? ?? '';
        final int duration = item['estimated_duration_minutes'] as int? ?? 0;
        
        String descriptionText = rawDescription;
        String priceText = "Price upon consultation";

        final lines = rawDescription.split('\n');
        List<String> descLines = [];
        List<String> priceLines = [];

        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          if (line.contains('Price:') || line.contains('Deposit:') || line.contains('Monthly:') || line.contains('RM')) {
             priceLines.add(line.trim());
          } else {
             descLines.add(line.trim());
          }
        }
        
        if (priceLines.isNotEmpty) {
          priceText = priceLines.join('\n');
        }
        if (descLines.isNotEmpty) {
          descriptionText = descLines.join(' ');
        }

        // Basic categorization logic based on keywords
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

        if (categorized.containsKey(category)) {
          categorized[category]!.add({
            'title': name,
            'duration': 'Est. $duration mins',
            'price': priceText,
            'raw_desc': descriptionText,
            'full_desc': rawDescription,
          });
        }
      }

      if (mounted) {
        setState(() {
          _servicesData = categorized;
          _isServicesLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading services for dashboard: $e');
      if (mounted) setState(() => _isServicesLoading = false);
    }
  }

  Future<void> _checkAndRequestNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasAsked = prefs.getBool('has_asked_notifications') ?? false;

    if (!hasAsked) {
      await Permission.notification.request();
      await prefs.setBool('has_asked_notifications', true);
    }
  }

  void _loadUserProfile() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      // Try to get from DB Patient table first if possible, or fallback to metadata
      // For simplicity here we use metadata + local state update like fetching profile
      // Ideally fetch from 'Patient' table similar to ProfileView
      setState(() {
        _userName = user.userMetadata?['full_name'] ?? "User";
        String? url = user.userMetadata?['avatar_url'];
        if (url != null) {
        _avatarUrl = "$url?t=${DateTime.now().millisecondsSinceEpoch}";
        }
      });
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
    setState(() {
      _selectedIndex = index;
      if (index == 0 || index == 3) {
        _loadUserProfile();
      }
    });
  }

  // --- Main Build ---
  @override
  Widget build(BuildContext context) {
    final Color navBarColor = const Color(0xFFFFF9C4);

    return Scaffold(
      backgroundColor: Colors.white,
      
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _getBody(),
      ),

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
    if (_selectedIndex == 2) return const ServicesView(); 
    if (_selectedIndex == 3) return const ProfileView();
    return Center(child: Text(AppTranslations.get('coming_soon')));
  }

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
            
            // Show loading or the list
            _isServicesLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFBC02D)))
                : _buildServicesList(),
                
            const SizedBox(height: 30),
            
            _buildDoctorsSection(),
          ],
        ),
      ),
    ); 
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        IconButton(
          icon: const Icon(Icons.logout), 
          color: Colors.redAccent,
          onPressed: () => _showLogoutConfirmation(context),
        ),
        GestureDetector(
          onTap: () => setState(() => _selectedIndex = 3),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFFBC02D), 
            backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                ? NetworkImage(_avatarUrl!)
                : null,
            child: _avatarUrl == null || _avatarUrl!.isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('logout')),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              _signOut(); 
            },
            child: Text(AppTranslations.get('logout'), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Align(
      alignment: Alignment.centerLeft, 
      child: Text(
        "${AppTranslations.get('hello')} $_userName", 
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
      )
    );
  }

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

  Widget _buildServicesList() {
    final currentServices = _servicesData[_selectedServiceCategory] ?? [];
    
    if (currentServices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(child: Text("No services available for $_selectedServiceCategory")),
      );
    }

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