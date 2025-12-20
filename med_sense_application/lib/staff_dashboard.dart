import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; 
import 'staff_message_view.dart'; 
import 'debug_message_view.dart'; // Import Debug View
import 'staff_services_management_view.dart';
import 'staff_appointments_view.dart';
import 'staff_management_view.dart';

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

  @override
  void initState() {
    super.initState();
    _displayName = widget.staffName ?? 
                   _supabase.auth.currentUser?.userMetadata?['full_name'] ?? 
                   "Staff";
    
    _displayRole = widget.staffRole ?? "Staff Member";
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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
                );
              }),
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
                );
              }),
              _buildStaffAction(Icons.manage_accounts, "Staff & Doctor Registry", "Manage clinic personnel", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StaffManagementView()),
                );
              }),
              _buildStaffAction(Icons.list_alt, "Queue System", "Monitor live queue", () {}),
            ] else ...[
              _buildStaffAction(Icons.calendar_today, "Appointments", "View bookings", () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StaffAppointmentsView()),
                );
              }),
              _buildStaffAction(Icons.chat, "Messages", "Chat with patients", () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StaffMessagesView()),
                );
              }),
              _buildStaffAction(Icons.list_alt, "Queue View", "Monitor live queue", () {}),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStaffAction(IconData icon, String title, String subtitle, VoidCallback onTap) {
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBC02D).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: const Color(0xFFFBC02D), size: 28),
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