import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:med_sense_application/main.dart'; 
import 'package:med_sense_application/screens/patient/location_view.dart'; 
import 'package:med_sense_application/screens/patient/services_view.dart'; 
import 'package:med_sense_application/screens/patient/profile_view.dart'; 
import 'package:med_sense_application/utils/translations.dart';
import 'package:med_sense_application/screens/chat/chat_screen.dart'; 
import 'package:med_sense_application/screens/booking/staff_selection_view.dart'; // Imported Staff Selection
import 'package:med_sense_application/screens/booking/booking_history_view.dart';
import 'package:med_sense_application/screens/patient/notification_view.dart';
import 'package:med_sense_application/services/notification_service.dart';

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

  // Chat Expansion State
  bool _isChatExpanded = false;
  late AnimationController _chatAnimationController;

  // Doctors Data
  bool _isDoctorsLoading = true;
  List<Map<String, dynamic>> _topDoctors = [];

  // Appointment Data
  bool _isAppointmentLoading = true;
  Map<String, dynamic>? _upcomingAppointment;

  // Queue Data
  bool _isQueueLoading = true;
  Map<String, dynamic>? _queueData;

  // Notifications
  int _unreadNotificationsCount = 0;
  bool _hasNewBooking = false; 
  bool _hasUnreadChat = false; // New state for chat red dot
  RealtimeChannel? _notificationChannel;

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadUserProfile();
    _fetchTopDoctors();
    _fetchUpcomingAppointment();
    _fetchOrGenerateQueueEntry(); 
    _fetchUnreadNotificationsCount();
    _checkBookingNotification(); 
    _checkUnreadChat(); // Check for unread chats
    
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
    _notificationChannel?.unsubscribe();
    _chatAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    await NotificationService().init();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Notification Subscription
    _notificationChannel = _supabase.channel('public:Notification:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Notification',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: user.id,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              final message = newRecord['message_content'] as String? ?? 'New Notification';
              
              // Show Local Notification
              NotificationService().showNotification(
                DateTime.now().millisecondsSinceEpoch ~/ 1000, 
                'MedSense', 
                message
              );

              // Update badge count
              _fetchUnreadNotificationsCount();
            }
          },
        )
        .subscribe();
        
    // Listen for New Messages (Chat)
    _supabase.channel('public:Message:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Message',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: user.id,
          ),
          callback: (payload) {
             // Refresh unread status
             _checkUnreadChat();
             // Optional: Show banner notification if app is in foreground but chat not open?
          },
        )
        .subscribe();

    // Queue Subscription (Listen for status updates)
    _supabase.channel('public:QueueEntry:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'QueueEntry',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'patient_id',
            value: user.id,
          ),
          callback: (payload) {
             _fetchOrGenerateQueueEntry();
          },
        )
        .subscribe();
  }

  Future<void> _checkUnreadChat() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastViewedStr = prefs.getString('last_viewed_chat_time');
      
      // If never viewed, everything is "unread" if messages exist, 
      // but usually we default to no dot until we have a baseline or just check if any message exists.
      // Let's assume if no key, we check if any message exists.
      
      dynamic query = _supabase.from('Message').select('message_id').eq('recipient_id', user.id);
      
      if (lastViewedStr != null) {
        query = query.gt('sent_at', lastViewedStr);
      }
      
      // Re-doing query safely to just check existence (boolean)
      var checkQuery = _supabase
          .from('Message')
          .select('message_id')
          .eq('recipient_id', user.id);
          
      if (lastViewedStr != null) {
        checkQuery = checkQuery.gt('sent_at', lastViewedStr);
      }
      
      final res = await checkQuery.limit(1).maybeSingle();
      
      if (mounted) {
        setState(() {
          _hasUnreadChat = res != null;
        });
      }
    } catch (e) {
      debugPrint("Error checking unread chat: $e");
    }
  }

  Future<void> _fetchUnreadNotificationsCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase
          .from('Notification')
          .count(CountOption.exact)
          .eq('recipient_id', user.id)
          .eq('is_read', false);

      if (mounted) {
        setState(() {
          _unreadNotificationsCount = response;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notification count: $e');
    }
  }

  Future<void> _checkBookingNotification() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hasNewBooking = prefs.getBool('has_new_booking') ?? false;
      });
    }
  }

  // --- Queue Logic ---
  Future<void> _fetchOrGenerateQueueEntry() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isQueueLoading = false);
      return;
    }

    try {
      final now = DateTime.now();
      // Start of today (UTC for Supabase comparison if needed, but here we construct generic ISO)
      // We rely on Supabase to handle timestamp comparison correctly if we pass ISO string
      final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final tomorrowStart = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();
      
      // 1. Check existing active queue for today
      final existingQueue = await _supabase
          .from('QueueEntry')
          .select('*, Doctor(name)')
          .eq('patient_id', user.id)
          .gte('check_in_time', todayStart)
          .lt('check_in_time', tomorrowStart)
          .neq('status', 'Completed')
          .neq('status', 'Missed')
          .neq('status', 'Cancelled')
          .limit(1)
          .maybeSingle();

      if (existingQueue != null) {
        if (mounted) {
          setState(() {
            _queueData = existingQueue;
            _isQueueLoading = false;
          });
        }
        return;
      }

      // 2. If no queue, check for eligible appointment (< 12 hours)
      final limitTime = now.add(const Duration(hours: 12)).toUtc().toIso8601String();
      final nowUtcStr = now.toUtc().toIso8601String();

      final eligibleAppointment = await _supabase
          .from('Appointment')
          .select()
          .eq('patient_id', user.id)
          .eq('status', 'Confirmed')
          .gte('appointment_datetime', nowUtcStr)
          .lte('appointment_datetime', limitTime)
          .order('appointment_datetime', ascending: true)
          .limit(1)
          .maybeSingle();

      if (eligibleAppointment != null) {
        // GENERATE NEW QUEUE NUMBER
        // Fetch max queue number for today to increment
        final maxQueueRes = await _supabase
            .from('QueueEntry')
            .select('queue_number')
            .gte('check_in_time', todayStart)
            .lt('check_in_time', tomorrowStart)
            .order('queue_number', ascending: false)
            .limit(1)
            .maybeSingle();

        int nextNum = 1;
        if (maxQueueRes != null) {
          nextNum = (maxQueueRes['queue_number'] as int) + 1;
        }

        final newQueue = await _supabase
            .from('QueueEntry')
            .insert({
              'patient_id': user.id,
              'doctor_id': eligibleAppointment['doctor_id'],
              'service_id': eligibleAppointment['service_id'],
              'appointment_id': eligibleAppointment['appointment_id'],
              'queue_number': nextNum,
              'status': 'Waiting',
            })
            .select('*, Doctor(name)')
            .single();

        if (mounted) {
          setState(() {
            _queueData = newQueue;
            _isQueueLoading = false;
          });
        }
      } else {
         if (mounted) setState(() => _isQueueLoading = false);
      }

    } catch (e) {
      debugPrint("Queue Error: $e");
      if (mounted) setState(() => _isQueueLoading = false);
    }
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
              onPressed: () async {
                // Navigate to Staff Selection
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StaffSelectionView()),
                );
                setState(() {
                   _isChatExpanded = false;
                   _checkUnreadChat(); // Refresh status on return
                });
              },
              backgroundColor: Colors.teal,
              label: Row(
                children: [
                  Text(AppTranslations.get('chat_with_staff'), style: const TextStyle(color: Colors.white)),
                  if (_hasUnreadChat) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ]
                ],
              ),
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _isChatExpanded ? Icons.close : Icons.chat_bubble_outline,
                  color: Colors.black,
                ),
                if (_hasUnreadChat && !_isChatExpanded)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
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
      _fetchTopDoctors(),
      _fetchUpcomingAppointment(),
      _fetchOrGenerateQueueEntry(),
      _fetchUnreadNotificationsCount(),
      _checkBookingNotification(),
      _checkUnreadChat(),
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

              _buildQueueBanner(),
              if (_queueData != null) const SizedBox(height: 20),
              
              _buildAppointmentBanner(),
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
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.black54),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationView()));
                    _fetchUnreadNotificationsCount(); // Refresh count on return
                  },
                ),
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.history, color: Colors.black54),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingHistoryView()));
                    _checkBookingNotification(); // Refresh on return
                  },
                ),
                if (_hasNewBooking)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
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

  Future<void> _confirmArrival() async {
    if (_queueData == null) return;
    
    // Confirmation Dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Check-in"),
          content: const Text(
            "Please ensure you have arrived at the clinic before checking in.\n\n"
            "If you are not present when called, your appointment may be cancelled by the staff."
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBC02D)),
              child: const Text("I am here", style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final queueId = _queueData!['queue_id'];

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final updated = await _supabase
          .from('QueueEntry')
          .update({'arrival_time': now})
          .eq('queue_id', queueId)
          .select()
          .single();

      if (mounted) {
        setState(() {
          _queueData = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You have successfully checked in!")),
        );
      }
    } catch (e) {
      debugPrint("Error confirming arrival: $e");
      // Fallback/Demo if column missing
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Check-in failed (DB Error): $e")),
        );
      }
    }
  }

  Widget _buildQueueBanner() {
    if (_isQueueLoading || _queueData == null) return const SizedBox.shrink();

    final queueNum = _queueData!['queue_number'];
    final status = _queueData!['status'];
    // arrival_time tracks the user's manual check-in
    final arrivalTimeStr = _queueData!['arrival_time'] as String?;
    
    // Doctor Name
    final doctor = _queueData!['Doctor'] as Map<String, dynamic>?;
    final doctorName = doctor != null ? doctor['name'] : 'Available Doctor';
    final doctorDisplay = doctorName.toString().startsWith("Dr.") ? doctorName : "Dr. $doctorName";

    // Room Number
    final roomNum = _queueData!['assigned_room'];
    String roomText = roomNum != null ? "Room $roomNum" : "Room: TBD";

    // Prediction Logic based on Appointment Time
    String predictionLabel = "Est. Arrival";
    String predictionTime = "--:--";
    
    if (_upcomingAppointment != null) {
       final dtStr = _upcomingAppointment!['appointment_datetime'] as String;
       final dt = DateTime.parse(dtStr).toLocal();
       // "Smart" Prediction: Suggest arriving 15 mins early
       final arrivalTime = dt.subtract(const Duration(minutes: 15));
       final amPm = arrivalTime.hour >= 12 ? 'PM' : 'AM';
       final hour = arrivalTime.hour > 12 ? arrivalTime.hour - 12 : (arrivalTime.hour == 0 ? 12 : arrivalTime.hour);
       predictionTime = "$hour:${arrivalTime.minute.toString().padLeft(2, '0')} $amPm";
    } else {
       // If no appointment logic but queue exists (e.g. walk-in), just show current time or "Now"
       predictionTime = "Now";
    }

    Color statusColor = const Color(0xFF2196F3); // Blue
    String statusText = "Waiting";
    
    if (status == 'Serving') {
      statusColor = const Color(0xFF4CAF50); // Green
      if (roomNum != null) {
        statusText = "Proceed to Room $roomNum";
      } else {
        statusText = "Proceed to Room"; 
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
           BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Doctor & Room info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.white70, size: 16),
                  const SizedBox(width: 5),
                  Text(doctorDisplay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5)
                ),
                child: Text(roomText, style: const TextStyle(color: Colors.white, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 15),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Queue Number", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    "$queueNum", 
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                // Section 1: Check In Status or Button
                Expanded(
                  child: arrivalTimeStr != null 
                    ? _buildCheckedInState(arrivalTimeStr)
                    : _buildCheckInButton(statusColor),
                ),
                
                // Vertical Divider
                Container(
                  width: 1, 
                  height: 40, 
                  color: Colors.white24, 
                  margin: const EdgeInsets.symmetric(horizontal: 10)
                ),
                
                // Section 2: Smart Estimation
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(predictionLabel, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_filled, color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(predictionTime, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCheckedInState(String arrivalTimeStr) {
    final dt = DateTime.parse(arrivalTimeStr).toLocal();
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final timeStr = "$hour:${dt.minute.toString().padLeft(2, '0')} $amPm";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Checked In", style: TextStyle(color: Colors.white70, fontSize: 10)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(timeStr, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildCheckInButton(Color primaryColor) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: _confirmArrival,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: primaryColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.touch_app, size: 18),
        label: const Text("Check In Now", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

    // Dynamic Badge Logic
    String badgeText = AppTranslations.get('upcoming');
    Color badgeColor = const Color(0xFFFFA000);

    if (_queueData != null && 
        _queueData!['appointment_id'] == apt['appointment_id']) {
         if (_queueData!['assigned_room'] != null) {
            badgeText = "Room ${_queueData!['assigned_room']}";
            badgeColor = Colors.green;
         } else if (_queueData!['status'] == 'Serving') {
            badgeText = "Now Serving";
            badgeColor = Colors.green;
         }
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
                  color: badgeColor, 
                  borderRadius: BorderRadius.circular(10)
                ), 
                child: Text(
                  badgeText, 
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