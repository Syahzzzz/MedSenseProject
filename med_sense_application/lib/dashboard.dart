import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'main.dart'; 
import 'location_view.dart'; 
import 'services_view.dart'; 
import 'profile_view.dart'; 
import 'translations.dart';
import 'chat_screen.dart'; 
import 'staff_selection_view.dart'; // Imported Staff Selection
import 'booking_history_view.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  // --- State & Dependencies ---
  final _supabase = Supabase.instance.client;
  String _userName = "User"; 
  String? _avatarUrl; 
  int _selectedIndex = 0; 
  String _selectedServiceCategory = 'Braces';

  // Chat Expansion State
  bool _isChatExpanded = false;
  late AnimationController _chatAnimationController;

  // Dynamic Services Data
  bool _isServicesLoading = true;
  Map<String, List<Map<String, String>>> _servicesData = {};

  // Doctors Data
  bool _isDoctorsLoading = true;
  List<Map<String, dynamic>> _topDoctors = [];

  // Appointment Data
  bool _isAppointmentLoading = true;
  Map<String, dynamic>? _upcomingAppointment;

  // --- Data Constants ---
  final List<String> _serviceCategories = ['Braces', 'Scaling', 'Whitening', 'Retainers', 'Others'];

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _fetchServices(); 
    _fetchTopDoctors();
    _fetchUpcomingAppointment(); // Added
    
    _chatAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestNotificationPermission();
    });
  }

  @override
  void dispose() {
    _chatAnimationController.dispose();
    super.dispose();
  }

  // --- Fetch Appointment ---
  Future<void> _fetchUpcomingAppointment() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isAppointmentLoading = false);
      return;
    }

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // 1. Auto-expire past appointments
      // Update any 'Confirmed' appointment that is in the past to 'Expired'
      await _supabase
          .from('Appointment')
          .update({'status': 'Expired'})
          .eq('patient_id', user.id)
          .eq('status', 'Confirmed')
          .lt('appointment_datetime', now);

      // 2. Fetch ONE upcoming appointment
      // We check where appointment_datetime >= NOW (UTC)
      final response = await _supabase
          .from('Appointment')
          .select('*, Service(service_name), Doctor(name, specialization)')
          .eq('patient_id', user.id)
          .eq('status', 'Confirmed') // Only confirmed ones
          .gte('appointment_datetime', now)
          .order('appointment_datetime', ascending: true)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _upcomingAppointment = response;
          _isAppointmentLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching upcoming appointment: $e');
      if (mounted) setState(() => _isAppointmentLoading = false);
    }
  }

  // --- Fetch Services from Supabase ---
  Future<void> _fetchServices() async {
    if (!mounted) return;
    setState(() => _isServicesLoading = true);
    
    try {
      // Fetch services from DB, now including the 'price' column
      final List<dynamic> response = await _supabase
          .from('Service') 
          .select('service_name, description, estimated_duration_minutes, price')
          .order('service_name', ascending: true);

      final Map<String, List<Map<String, String>>> categorized = {
        'Braces': [],
        'Scaling': [],
        'Whitening': [],
        'Retainers': [],
        'Others': [],
      };

      for (var item in response) {
        final String name = item['service_name'] as String;
        final String rawDescription = item['description'] as String? ?? '';
        final int duration = item['estimated_duration_minutes'] as int? ?? 0;
        final num priceVal = item['price'] as num? ?? 0;
        
        // Format price
        String priceText = "RM ${priceVal.toStringAsFixed(0)}"; 
        
        // Use description directly as it likely no longer contains price metadata
        String descriptionText = rawDescription;

        // Basic categorization logic based on keywords
        String category = 'Others';
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

  Future<void> _fetchTopDoctors() async {
    try {
      final response = await _supabase
          .from('Doctor')
          .select('name, specialization, years_experience')
          .gt('years_experience', 10)
          .order('years_experience', ascending: false) // Best first
          .limit(5);

      if (mounted) {
        setState(() {
          _topDoctors = List<Map<String, dynamic>>.from(response);
          _isDoctorsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching top doctors: $e');
      if (mounted) setState(() => _isDoctorsLoading = false);
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
    final Color primaryYellow = const Color(0xFFFBC02D);

    return Scaffold(
      backgroundColor: Colors.white,
      
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _getBody(),
      ),

      // --- Expandable Chat FAB ---
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isChatExpanded) ...[
            // Chat with Staff Button
            FloatingActionButton.extended(
              heroTag: 'chat_staff',
              onPressed: () {
                // Navigate to Staff Selection
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StaffSelectionView()),
                );
                setState(() => _isChatExpanded = false);
              },
              backgroundColor: Colors.teal,
              label: Text(AppTranslations.get('chat_with_staff'), style: const TextStyle(color: Colors.white)),
              icon: const Icon(Icons.people, color: Colors.white),
            ),
            const SizedBox(height: 12),
            
            // Chat with Bot Button
            FloatingActionButton.extended(
              heroTag: 'chat_bot',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatScreen(isBot: true)),
                );
                setState(() => _isChatExpanded = false);
              },
              backgroundColor: Colors.blueAccent,
              label: Text(AppTranslations.get('chat_with_bot'), style: const TextStyle(color: Colors.white)),
              icon: const Icon(Icons.smart_toy, color: Colors.white),
            ),
            const SizedBox(height: 12),
          ],
          
          // Main Toggle Button
          FloatingActionButton(
            heroTag: 'chat_toggle',
            onPressed: () {
              setState(() {
                _isChatExpanded = !_isChatExpanded;
                if (_isChatExpanded) {
                  _chatAnimationController.forward();
                } else {
                  _chatAnimationController.reverse();
                }
              });
            },
            backgroundColor: primaryYellow,
            child: Icon(
              _isChatExpanded ? Icons.close : Icons.chat_bubble_outline,
              color: Colors.black,
            ),
          ),
        ],
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

  Future<void> _refreshDashboard() async {
    _loadUserProfile();
    await Future.wait([
      _fetchServices(),
      _fetchTopDoctors(),
      _fetchUpcomingAppointment(),
    ]);
  }

  Widget _buildHome() {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      color: const Color(0xFFFBC02D),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24), 
          physics: const AlwaysScrollableScrollPhysics(), // Ensure scroll even if content is short
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
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.history, color: Colors.black54),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingHistoryView())),
            ),
            const SizedBox(width: 10),
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
    if (_isAppointmentLoading) {
      return Container(
         height: 150,
         width: double.infinity,
         decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
         child: const Center(child: CircularProgressIndicator(color: Color(0xFFFBC02D))),
      );
    }

    if (_upcomingAppointment == null) {
      return Container(
        width: double.infinity,
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
             const Icon(Icons.calendar_month_outlined, size: 40, color: Color(0xFFFBC02D)),
             const SizedBox(height: 10),
             const Text(
               "No Upcoming Appointments",
               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
             ),
             const SizedBox(height: 5),
             Text(
               "Book your next dental visit today!",
               style: TextStyle(color: Colors.grey[600], fontSize: 12),
             ),
          ],
        ),
      );
    }

    final apt = _upcomingAppointment!;
    final service = apt['Service'] as Map<String, dynamic>? ?? {};
    final doctor = apt['Doctor'] as Map<String, dynamic>? ?? {};
    final serviceName = service['service_name'] ?? 'General Consultation';
    final doctorName = doctor['name'] ?? 'Available Doctor';
    final specialization = doctor['specialization'] ?? AppTranslations.get('dentist');

    // Parse Date (Stored as UTC ISO, convert to Local)
    final dtStr = apt['appointment_datetime'] as String;
    final dt = DateTime.parse(dtStr).toLocal();
    
    final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = "${dt.day} ${months[dt.month-1]} ${dt.year}";
    
    int hour = dt.hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final timeStr = "$hour:$minuteStr $amPm";

    // Simple image logic
    String imageAsset = 'images/john.png';
    if (doctorName.toLowerCase().contains('sarah') || doctorName.toLowerCase().contains('jane') || doctorName.toLowerCase().contains('fatimah')) {
      imageAsset = 'images/sarah.png';
    }

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text(serviceName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        // Assuming location is static for now, or could be fetched from clinic if stored
                        Text(AppTranslations.get('dental_clinic_rawang'), style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
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
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(dateStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 15), 
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(timeStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
                backgroundImage: AssetImage(imageAsset), 
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctorName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    specialization, 
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
        
        if (_isDoctorsLoading)
           const Center(child: CircularProgressIndicator(color: Color(0xFFFBC02D)))
        else if (_topDoctors.isEmpty)
           Padding(
             padding: const EdgeInsets.all(20),
             child: Text("No top doctors found at the moment.", style: TextStyle(color: Colors.grey[600])),
           )
        else
          Column(
            children: _topDoctors.map((d) {
              // Simple image logic since DB doesn't have image column yet
              String imageAsset = 'images/john.png';
              final String name = d['name'].toString();
              if (name.toLowerCase().contains('sarah') || name.toLowerCase().contains('jane') || name.toLowerCase().contains('fatimah')) {
                imageAsset = 'images/sarah.png';
              }
              
              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                constraints: const BoxConstraints(minHeight: 100), // Flexible height
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
                            imageAsset,
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
                        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0), // Reduced vertical padding
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              d['specialization']!,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                             Text(
                              "${d['years_experience']} years exprience",
                              style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList()
          ),
      ],
    );
  }
}