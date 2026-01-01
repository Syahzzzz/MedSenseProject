import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert' as import_convert;
import 'package:shared_preferences/shared_preferences.dart'; // Import Shared Preferences
import 'package:med_sense_application/main.dart'; 
import 'package:med_sense_application/screens/staff/staff_message_view.dart'; 
import 'package:med_sense_application/screens/chat/debug_message_view.dart'; // Import Debug View
import 'package:med_sense_application/screens/staff/staff_services_management_view.dart';
import 'package:med_sense_application/screens/staff/staff_appointments_view.dart';
import 'package:med_sense_application/screens/staff/staff_management_view.dart';
import 'package:med_sense_application/screens/staff/staff_requests_view.dart'; // Import Request View
import 'package:med_sense_application/screens/staff/staff_queue_view.dart'; // Import Queue View
import 'package:med_sense_application/screens/staff/walk_in_registration_view.dart'; // Import Walk-In View

class StaffDashboard extends StatefulWidget {
  final String? staffName;
  final String? staffRole;
  final bool? isAdmin;

  const StaffDashboard({
    super.key, 
    this.staffName,
    this.staffRole,
    this.isAdmin,
  });

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  final _supabase = Supabase.instance.client;
  late String _displayName;
  late String _displayRole;
  
  // Notification Counts
  int _pendingAppointmentsCount = 0;
  int _patientRequestsCount = 0;
  int _unreadMessagesCount = 0;
  int _activeQueueCount = 0;

  RealtimeChannel? _dashboardChannel;

  @override
  void initState() {
    super.initState();
    _displayName = widget.staffName ?? 
                   _supabase.auth.currentUser?.userMetadata?['full_name'] ?? 
                   "Staff";
    
    _displayRole = widget.staffRole ?? "Staff Member";
    _fetchDashboardCounts();
    _subscribeToChanges();
  }

  @override
  void dispose() {
    _dashboardChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchDashboardCounts() async {
    try {
      // 1. Pending Appointments
      final appointmentsRes = await _supabase
          .from('Appointment')
          .count(CountOption.exact)
          .eq('status', 'Pending');
      
      // 2. Patient Requests
      final requestsRes = await _supabase
          .from('Appointment')
          .count(CountOption.exact)
          .or('status.eq.Cancellation Requested,status.eq.Reschedule Requested');

      // 3. Unread Messages (Client-Side Logic)
      int messagesRes = 0;
      try {
        final prefs = await SharedPreferences.getInstance();
        String? targetId = prefs.getString('current_staff_id');
        
        // If not in prefs, try to resolve via email
        if (targetId == null) {
          final user = _supabase.auth.currentUser;
          if (user != null && user.email != null) {
             final staffRecord = await _supabase
                .from('Staff')
                .select('staff_id')
                .eq('email', user.email!)
                .maybeSingle();
             if (staffRecord != null) {
               targetId = staffRecord['staff_id'];
               await prefs.setString('current_staff_id', targetId!);
             }
          }
        }

        if (targetId != null) {
          // Fetch recent messages to determine unread status per conversation
          // We limit to 50 for performance, assuming unread messages are recent
          final msgs = await _supabase
              .from('Message')
              .select('sender_id, recipient_id, sent_at')
              .or('sender_id.eq.$targetId,recipient_id.eq.$targetId')
              .order('sent_at', ascending: false)
              .limit(50);

          // Load read timestamps
          String? jsonStr = prefs.getString('read_timestamps');
          Map<String, dynamic> readTimestamps = {};
          if (jsonStr != null) {
            try {
              readTimestamps = import_convert.jsonDecode(jsonStr);
            } catch (_) {}
          }

          final Set<String> unreadSenders = {};

          for (var m in msgs) {
            final sender = m['sender_id'].toString();
            // Only check incoming messages (where I am recipient)
            if (sender != targetId) {
               final sentAtStr = m['sent_at'] as String;
               final sentAt = DateTime.parse(sentAtStr); // Supabase returns UTC ISO
               
               final lastReadStr = readTimestamps[sender];
               
               bool isUnread = false;
               if (lastReadStr == null) {
                 isUnread = true; // Never read this person
               } else {
                 final lastRead = DateTime.parse(lastReadStr); // Saved as UTC ISO
                 if (sentAt.isAfter(lastRead)) {
                   isUnread = true;
                 }
               }
               
               if (isUnread) {
                 unreadSenders.add(sender);
               }
            }
          }
          messagesRes = unreadSenders.length;
        }
      } catch (e) {
        debugPrint("Message count failed: $e");
      }

      // 4. Active Queue
      final queueRes = await _supabase
          .from('QueueEntry')
          .count(CountOption.exact)
          .or('status.eq.Waiting,status.eq.Serving');

      debugPrint("Dashboard Counts - Appointments: $appointmentsRes, Requests: $requestsRes, Messages: $messagesRes, Queue: $queueRes");

      if (mounted) {
        setState(() {
          _pendingAppointmentsCount = appointmentsRes;
          _patientRequestsCount = requestsRes;
          _unreadMessagesCount = messagesRes;
          _activeQueueCount = queueRes;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard counts: $e');
    }
  }

  void _subscribeToChanges() {
    _dashboardChannel = _supabase.channel('public:staff_dashboard')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Appointment',
        callback: (payload) => _fetchDashboardCounts(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Message',
        callback: (payload) => _fetchDashboardCounts(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'QueueEntry',
        callback: (payload) => _fetchDashboardCounts(),
      )
      .subscribe();
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MyHomePage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryYellow = Color(0xFFFBC02D);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Staff Dashboard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // DEBUG BUTTON - Click this to check message IDs
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orange),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const DebugMessageView())
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardCounts,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryYellow.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.medical_services, size: 60, color: primaryYellow),
              ),
              const SizedBox(height: 24),
              Text(
                "Welcome, $_displayName",
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  _displayRole.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12, 
                    color: Colors.grey.shade800, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 1.2
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Staff Actions List
              if (widget.isAdmin == true) ...[
                _buildStaffAction(Icons.calendar_today, "Appointments Management", "View and manage bookings", () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StaffAppointmentsView()),
                  ).then((_) => _fetchDashboardCounts());
                }, badgeCount: _pendingAppointmentsCount),
                
                _buildStaffAction(Icons.person_add, "Walk-In Registration", "Register immediate walk-in patients", () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WalkInRegistrationView()),
                  ).then((_) => _fetchDashboardCounts());
                }),

                _buildStaffAction(Icons.approval, "Patient Requests", "Handle cancellations & rescheduling", () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StaffRequestsView()),
                  ).then((_) => _fetchDashboardCounts());
                }, badgeCount: _patientRequestsCount),
                
                _buildStaffAction(Icons.edit_note, "Services Management", "Add, edit, or remove services", () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const StaffServicesManagementView())
                  );
                }),
                
                _buildStaffAction(Icons.chat, "Patient Messages", "Chat with patients", () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StaffMessagesView()),
                  ).then((_) => _fetchDashboardCounts());
                }, badgeCount: _unreadMessagesCount),
                
                _buildStaffAction(Icons.manage_accounts, "Staff & Doctor Registry", "Manage clinic personnel", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StaffManagementView()),
                  );
                }),
                
                _buildStaffAction(Icons.list_alt, "Queue System", "Monitor live queue", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StaffQueueView()),
                  ).then((_) => _fetchDashboardCounts());
                }, badgeCount: _activeQueueCount),
                
              ] else ...[
                _buildStaffAction(Icons.calendar_today, "Appointments", "View bookings", () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StaffAppointmentsView()),
                  ).then((_) => _fetchDashboardCounts());
                }, badgeCount: _pendingAppointmentsCount),

                _buildStaffAction(Icons.person_add, "Walk-In Registration", "Register immediate walk-in patients", () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WalkInRegistrationView()),
                  ).then((_) => _fetchDashboardCounts());
                }),
                
                _buildStaffAction(Icons.approval, "Patient Requests", "Handle cancellations & rescheduling", () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StaffRequestsView()),
                  ).then((_) => _fetchDashboardCounts());
                }, badgeCount: _patientRequestsCount),
                
                _buildStaffAction(Icons.chat, "Messages", "Chat with patients", () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StaffMessagesView()),
                  ).then((_) => _fetchDashboardCounts());
                }, badgeCount: _unreadMessagesCount),
                
                _buildStaffAction(Icons.list_alt, "Queue View", "Monitor live queue", () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StaffQueueView()),
                  ).then((_) => _fetchDashboardCounts());
                }, badgeCount: _activeQueueCount),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaffAction(IconData icon, String title, String subtitle, VoidCallback onTap, {int badgeCount = 0}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 2,
          )
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBC02D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(icon, color: const Color(0xFFFBC02D), size: 28),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              badgeCount > 99 ? '99+' : '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title, 
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: Colors.black87,
                          fontSize: 16
                        )
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle, 
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13
                        )
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}