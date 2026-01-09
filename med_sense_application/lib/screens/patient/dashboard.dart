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
import 'package:med_sense_application/services/tts_manager.dart';
import 'package:workmanager/workmanager.dart'; // Import Workmanager

import 'package:med_sense_application/widgets/custom_bottom_navigation.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  // --- State & Dependencies ---
  final _supabase = Supabase.instance.client;
  final TtsManager _tts = TtsManager(); // TTS Manager
  String _userName = "User"; 
  String? _avatarUrl; 
  int _selectedIndex = 0; 
  bool _isOkuEnabled = false; // OKU Mode State

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
  String? _lastQueueStatus;
  int _peopleAhead = 0;
  String _trafficStatus = "Clear";
  int _travelTimeMinutes = 20; // Default base

  // Notifications
  int _unreadNotificationsCount = 0;
  bool _hasNewBooking = false; 
  bool _hasUnreadChat = false; // New state for chat red dot
  RealtimeChannel? _notificationChannel;

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _tts.init(); // Initialize TTS
    _loadOkuSettings(); // Load OKU settings first
    _initializeNotifications();
    _registerBackgroundTask(); // Register Background Task
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

    // Listen for language changes
    appLanguageNotifier.addListener(_onLanguageChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestNotificationPermission();
    });
  }

  @override
  void dispose() {
    appLanguageNotifier.removeListener(_onLanguageChanged);
    _notificationChannel?.unsubscribe();
    _chatAnimationController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadOkuSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isOkuEnabled = prefs.getBool('is_oku_enabled') ?? false;
        _tts.setEnabled(_isOkuEnabled); // Sync TTS state
      });
    }
  }

  void _onOkuChanged(bool enabled) {
    setState(() {
      _isOkuEnabled = enabled;
      _tts.setEnabled(enabled); // Sync TTS state
    });
  }

  void _registerBackgroundTask() {
    // Unique name for the task
    Workmanager().registerPeriodicTask(
      "medsense_notification_check", 
      "checkNotifications", 
      frequency: const Duration(minutes: 15), // Minimum allowed on Android
      constraints: Constraints(
        networkType: NetworkType.connected, // Needs internet
      ),
      initialDelay: const Duration(seconds: 10), // Run shortly after app start for testing
    );
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
             final newRecord = payload.newRecord;
             if (newRecord['sender_id'] != user.id) {
               // Directly set unread status to ensure red dot appears immediately
               if (mounted) {
                 setState(() {
                   _hasUnreadChat = true;
                 });
                 // Refresh count if we had logic for it
                 _fetchUnreadNotificationsCount();
               }
             }
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
             
             final newRecord = payload.newRecord;
             if (newRecord['status'] == 'Serving') {
               // 1. Notification
               NotificationService().showNotification(
                 DateTime.now().millisecondsSinceEpoch ~/ 1000, 
                 'MedSense Queue', 
                 "It's your turn! Please proceed to the room."
               );
               
               // 2. Popup
               if (mounted) {
                 _showNowServingDialog(newRecord);
               }
             }
          },
        )
        .subscribe();
  }

  void _showNowServingDialog(Map<String, dynamic> record) {
    final room = record['assigned_room'] ?? "the assigned room";
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.green),
            SizedBox(width: 10),
            Text("It's Your Turn!", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Your queue number ${record['queue_number']} has been called.\n\nPlease proceed to Room $room immediately.",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("I'm on my way", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
          .select('*, Doctor(name, specialization), Appointment(appointment_datetime, Service(service_name))')
          .eq('patient_id', user.id)
          .gte('check_in_time', todayStart)
          .lt('check_in_time', tomorrowStart)
          .neq('status', 'Completed')
          .neq('status', 'Missed')
          .neq('status', 'Cancelled')
          .limit(1)
          .maybeSingle();

      if (existingQueue != null) {
        // Calculate People Ahead
        final myQueueNum = existingQueue['queue_number'] as int;
        final doctorId = existingQueue['doctor_id'];
        final currentStatus = existingQueue['status'] as String?;
        final doctorName = existingQueue['Doctor']?['name'] ?? 'Unknown';
        
        // STATUS CHANGE DETECTION (Serving)
        if (currentStatus == 'Serving' && _lastQueueStatus != 'Serving') {
           NotificationService().showNotification(
             DateTime.now().millisecondsSinceEpoch ~/ 1000, 
             'MedSense Queue', 
             "It's your turn! Please proceed to the room."
           );
           if (mounted) _showNowServingDialog(existingQueue);
        }
        _lastQueueStatus = currentStatus;

        final peopleCount = await _supabase
            .from('QueueEntry')
            .count(CountOption.exact)
            .eq('doctor_id', doctorId)
            .eq('status', 'Waiting')
            .lt('queue_number', myQueueNum);

        _calculateTrafficInfo(doctorName);

        if (mounted) {
          setState(() {
            _queueData = existingQueue;
            _peopleAhead = peopleCount;
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
          .select('*, Doctor(name)') // Fetch doctor name for traffic calc
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

        int nextNum = 2001;
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
            .select('*, Doctor(name, specialization), Appointment(appointment_datetime, Service(service_name))')
            .single();
        
        final doctorName = eligibleAppointment['Doctor']?['name'] ?? 'Unknown';
        _calculateTrafficInfo(doctorName);
        
        // New entry, so people ahead is likely 0 unless we query again, but let's assume 0 or query:
        // Actually, better to query to be safe
        final peopleCount = await _supabase
            .from('QueueEntry')
            .count(CountOption.exact)
            .eq('doctor_id', eligibleAppointment['doctor_id'])
            .eq('status', 'Waiting')
            .lt('queue_number', nextNum);

        if (mounted) {
          setState(() {
            _queueData = newQueue;
            _peopleAhead = peopleCount;
            _isQueueLoading = false;
          });
          _showQueuePopup();
        }
      } else {
         if (mounted) setState(() => _isQueueLoading = false);
      }

    } catch (e) {
      debugPrint("Queue Error: $e");
      if (mounted) setState(() => _isQueueLoading = false);
    }
  }

  String _getClinicKeyForDoctor(String doctorName) {
    // Mock Logic for Multi-Clinic Support
    final name = doctorName.toLowerCase();
    if (name.contains('sarah') || name.contains('jane') || name.contains('lee')) {
      return 'dental_clinic_rawang';
    } else if (name.contains('ali') || name.contains('ahmad') || name.contains('tan')) {
      return 'dental_clinic_selayang';
    } else {
      return 'dental_clinic_kl';
    }
  }

  void _calculateTrafficInfo(String doctorName) {
    final now = DateTime.now();
    final hour = now.hour;
    final clinicKey = _getClinicKeyForDoctor(doctorName);
    
    // Base Travel Time by Location (Mock)
    int baseMinutes = 20; // Rawang (Closest)
    if (clinicKey == 'dental_clinic_selayang') {
      baseMinutes = 35;
    }
    if (clinicKey == 'dental_clinic_kl') {
      baseMinutes = 60;
    }

    // Traffic Multiplier
    double multiplier = 1.0;
    
    // Malaysia Traffic Simulation
    // Morning Peak: 7-9
    // Evening Peak: 17-19
    // Lunch: 12-14
    
    if ((hour >= 7 && hour < 10) || (hour >= 17 && hour < 20)) {
      _trafficStatus = "Heavy (Peak Hour)";
      multiplier = 1.5; // +50% time
    } else if (hour >= 12 && hour < 14) {
      _trafficStatus = "Moderate";
      multiplier = 1.2; // +20% time
    } else {
      _trafficStatus = "Clear";
      multiplier = 1.0;
    }

    _travelTimeMinutes = (baseMinutes * multiplier).round();
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

  void _showQueuePopup() {
    if (!mounted || _queueData == null) return;
    
    // Extract data
    final doctor = _queueData!['Doctor'] as Map<String, dynamic>?;
    final doctorName = doctor != null ? doctor['name'] : 'Unknown';
    // specialization is fetched now
    // final specialization = doctor != null ? doctor['specialization'] : '';

    final appointment = _queueData!['Appointment'] as Map<String, dynamic>?;
    String serviceName = 'General Consultation';
    String timeStr = 'Today';
    
    if (appointment != null) {
      final service = appointment['Service'] as Map<String, dynamic>?;
      if (service != null) {
        serviceName = service['service_name'] ?? serviceName;
      }
      
      final dtStr = appointment['appointment_datetime'] as String?;
      if (dtStr != null) {
         final dt = DateTime.parse(dtStr).toLocal();
         final amPm = dt.hour >= 12 ? 'PM' : 'AM';
         final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
         final min = dt.minute.toString().padLeft(2, '0');
         timeStr = "$hour:$min $amPm";
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Current Queue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text(
                "${_queueData!['queue_number']}",
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Color(0xFFFBC02D)),
              ),
              const SizedBox(height: 10),
               Text(
                "Status: ${_queueData!['status']}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              
              // Details
              Row(
                children: [
                  const Icon(Icons.person, size: 20, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text("Dr. $doctorName", style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.medical_services, size: 20, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 20, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(timeStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Close", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        );
      },
    );
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

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        setState(() {
          _selectedIndex = 0;
        });
      },
      child: Scaffold(
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
                  MaterialPageRoute(
                    builder: (context) => StaffSelectionView(isOkuMode: _isOkuEnabled),
                  ),
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
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      isBot: true,
                      isOkuMode: _isOkuEnabled,
                    ),
                  ),
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

      bottomNavigationBar: _isOkuEnabled ? null : CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        backgroundColor: navBarColor,
      ),
    ));
  }

  // --- Helper Widgets ---

  Future<void> _openChatStaff() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StaffSelectionView(isOkuMode: _isOkuEnabled),
      ),
    );
    setState(() {
      _isChatExpanded = false;
      _checkUnreadChat();
    });
  }

  void _openChatBot() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          isBot: true,
          isOkuMode: _isOkuEnabled,
        ),
      ),
    );
    setState(() => _isChatExpanded = false);
  }

  Widget _getBody() {
    final VoidCallback? okuBackAction = _isOkuEnabled 
      ? () => setState(() => _selectedIndex = 0)
      : null;

    if (_selectedIndex == 0) {
      return _buildHome();
    }
    if (_selectedIndex == 1) {
      return LocationView(
          onBack: okuBackAction ?? () => setState(() => _selectedIndex = 0),
          isOkuMode: _isOkuEnabled,
          onChatStaff: _openChatStaff,
          onChatBot: _openChatBot);
    }
    if (_selectedIndex == 2) {
      return ServicesView(
          onBack: okuBackAction,
          isOkuMode: _isOkuEnabled,
          onChatStaff: _openChatStaff,
          onChatBot: _openChatBot);
    }
    if (_selectedIndex == 3) {
      return ProfileView(
          onBack: okuBackAction, onOkuChanged: _onOkuChanged);
    }
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

              if (!_isOkuEnabled) ...[
                _buildQueueBanner(),
                if (_queueData != null) const SizedBox(height: 20),
                
                _buildAppointmentBanner(),
                const SizedBox(height: 30),
                
                _buildDoctorsSection(),
              ] else ...[
                 // OKU MODE: Big Buttons
                 const SizedBox(height: 10),
                 if (_queueData != null) ...[
                    _buildQueueBanner(),
                    const SizedBox(height: 20),
                 ],
                 if (_upcomingAppointment != null) ...[
                    _buildAppointmentBanner(),
                    const SizedBox(height: 20),
                 ],
                 
                 _buildBigButton("Booking", Icons.calendar_month, const Color(0xFF5E35B1), () => setState(() => _selectedIndex = 2)),
                 _buildBigButton("Booking History", Icons.history, const Color(0xFF00ACC1), () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingHistoryView()));
                    _checkBookingNotification();
                 }, hasUpdate: _hasNewBooking),
                 _buildBigButton("Notifications", Icons.notifications, const Color(0xFF3949AB), () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationView()));
                    _fetchUnreadNotificationsCount();
                 }, hasUpdate: _unreadNotificationsCount > 0),
                 _buildBigButton("Profile", Icons.person, const Color(0xFFD81B60), () => setState(() => _selectedIndex = 3)),
                 _buildBigButton("Location", Icons.location_on, const Color(0xFF43A047), () => setState(() => _selectedIndex = 1)),

                 // Chat Buttons (Added for OKU Mode Home)
                 _buildBigButton(AppTranslations.get('chat_with_staff'), Icons.people, const Color(0xFFFF8F00), _openChatStaff, hasUpdate: _hasUnreadChat),
                 _buildBigButton(AppTranslations.get('chat_with_bot'), Icons.smart_toy, const Color(0xFF1E88E5), _openChatBot),
              ],
            ],
          ),
        ),
      ),
    ); 
  }

  Widget _buildBigButton(String title, IconData icon, Color color, VoidCallback onTap, {bool hasUpdate = false}) {
    return GestureDetector(
      onTap: () {
        if (_isOkuEnabled) {
          _tts.speak(title);
        }
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: hasUpdate ? Border.all(color: Colors.red, width: 4.0) : null,
          boxShadow: [
             BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(width: 15),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
    final arrivalTimeStr = _queueData!['arrival_time'] as String?;
    
    // Doctor Name
    final doctor = _queueData!['Doctor'] as Map<String, dynamic>?;
    final doctorName = doctor != null ? doctor['name'] : 'Available Doctor';
    final doctorDisplay = doctorName.toString().startsWith("Dr.") ? doctorName : "Dr. $doctorName";

    // Clinic Name
    final clinicKey = _getClinicKeyForDoctor(doctorName.toString());
    final clinicName = AppTranslations.get(clinicKey);

    // Room Number
    final roomNum = _queueData!['assigned_room'];
    String roomText = roomNum != null ? "Room $roomNum" : "Room: TBD";

    Color statusColor = const Color(0xFF2196F3); // Blue
    String statusText = "Waiting";
    
    if (status == 'Serving') {
      statusColor = const Color(0xFF4CAF50); // Green
      statusText = "Now Serving";
    } else if (status == 'Missed') {
      statusColor = Colors.red;
      statusText = "Missed";
    }

    // --- Prediction Logic ---
    final now = DateTime.now();
    DateTime estServiceTime;

    // Check for Appointment Time
    final appointment = _queueData!['Appointment'] as Map<String, dynamic>?;
    DateTime? appointmentTime;
    if (appointment != null && appointment['appointment_datetime'] != null) {
      appointmentTime = DateTime.parse(appointment['appointment_datetime']).toLocal();
    }

    if (appointmentTime != null && appointmentTime.isAfter(now)) {
       // Primary: Base on Appointment Time if it's in the future
       estServiceTime = appointmentTime;
    } else {
       // Fallback: Queue-based (Walk-in or Late/Current)
       int estWaitMinutes = _peopleAhead * 15;
       if (estWaitMinutes == 0 && status == 'Waiting') estWaitMinutes = 5;
       if (status == 'Serving') estWaitMinutes = 0;
       estServiceTime = now.add(Duration(minutes: estWaitMinutes));
    }
    
    // Target Arrival: 30 mins before service to be safe
    final targetArrival = estServiceTime.subtract(const Duration(minutes: 30));
    
    // Time to Leave: Target Arrival - Travel Time
    final timeToLeave = targetArrival.subtract(Duration(minutes: _travelTimeMinutes));

    // Formatting
    String formatTime(DateTime dt) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return "$hour:$min $amPm";
    }

    // Traffic Color
    Color trafficColor = Colors.greenAccent;
    if (_trafficStatus.contains("Heavy")) trafficColor = Colors.redAccent;
    if (_trafficStatus.contains("Moderate")) trafficColor = Colors.orangeAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withBlue(((statusColor.b * 255).round() + 20).clamp(0, 255))],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
           BoxShadow(
            color: statusColor.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: Doctor & Room
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.medical_services_outlined, color: Colors.white70, size: 24),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctorDisplay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(clinicName, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Text(roomText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              )
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Main Queue Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Queue Number", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  Text(
                    "$queueNum", 
                    style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold, height: 1.1)
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (status == 'Waiting')
                    Text("$_peopleAhead people ahead", style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              )
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Smart Prediction Card (Embedded)
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                // Row 1: Traffic Info
                Row(
                  children: [
                    Icon(Icons.traffic, color: trafficColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Traffic: $_trafficStatus", 
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)
                      ),
                    ),
                    Text(
                      "+$_travelTimeMinutes min", 
                      style: const TextStyle(color: Colors.white70, fontSize: 13)
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                
                // Row 2: Prediction Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPredictionItem("Est. Service", formatTime(estServiceTime)),
                    _buildPredictionItem("Target Arrival", formatTime(targetArrival)),
                    _buildPredictionItem("Time to Leave", formatTime(timeToLeave), isHighlight: true),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Action Button (Check In)
          if (arrivalTimeStr == null && status != 'Completed' && status != 'Missed')
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: _confirmArrival,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: statusColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.touch_app),
                label: const Text("I have arrived at the clinic", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          else if (arrivalTimeStr != null)
             Container(
               padding: const EdgeInsets.symmetric(vertical: 10),
               width: double.infinity,
               decoration: BoxDecoration(
                 border: Border.all(color: Colors.white30),
                 borderRadius: BorderRadius.circular(12)
               ),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Icon(Icons.check_circle, color: Colors.white, size: 20),
                   const SizedBox(width: 8),
                   const Text("You are checked in", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                   const SizedBox(width: 8),
                   Text("(${formatTime(DateTime.parse(arrivalTimeStr).toLocal())})", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                 ],
               ),
             )
        ],
      ),
    );
  }

  Widget _buildPredictionItem(String label, String time, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          time, 
          style: TextStyle(
            color: isHighlight ? const Color(0xFFFFD740) : Colors.white, // Amber for highlight
            fontSize: 15, 
            fontWeight: FontWeight.bold
          )
        ),
      ],
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
                        // Fetch clinic based on doctor
                        Text(AppTranslations.get(_getClinicKeyForDoctor(doctorName)), style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
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