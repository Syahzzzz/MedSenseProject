import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; 
import 'staff_message_view.dart'; 
import 'debug_message_view.dart'; // Import Debug View
import 'staff_services_management_view.dart';
import 'staff_appointments_view.dart';

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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medical_services, size: 100, color: primaryYellow),
            const SizedBox(height: 20),
            Text(
              "Welcome, $_displayName",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              _displayRole.toUpperCase(),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 10),
            const Text(
              "Clinic Management Panel",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            
            // Staff Actions Grid
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                if (widget.isAdmin == true) ...[
                  _buildStaffAction(Icons.edit_note, "Add/Edit Service", () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const StaffServicesManagementView())
                    );
                  }),
                  _buildStaffAction(Icons.chat, "Messages", () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StaffMessagesView()),
                    );
                  }),
                  _buildStaffAction(Icons.calendar_today, "Appointments", () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StaffAppointmentsView()),
                    );
                  }),
                  _buildStaffAction(Icons.manage_accounts, "Reg/Edit Staff", () {}),
                  _buildStaffAction(Icons.list_alt, "View Queue", () {}),
                ] else ...[
                  _buildStaffAction(Icons.calendar_today, "Appointments", () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StaffAppointmentsView()),
                    );
                  }),
                  _buildStaffAction(Icons.chat, "Messages", () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StaffMessagesView()),
                    );
                  }),
                  _buildStaffAction(Icons.list_alt, "View Queue", () {}),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 100,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFFBC02D), size: 30),
            const SizedBox(height: 10),
            Text(
              label, 
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold, 
                color: Colors.black87,
                fontSize: 13
              )
            ),
          ],
        ),
      ),
    );
  }
}