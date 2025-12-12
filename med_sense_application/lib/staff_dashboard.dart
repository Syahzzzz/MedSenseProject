import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; 
import 'staff_message_view.dart'; // Import Messages View

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medical_services, size: 100, color: Colors.blueGrey),
            const SizedBox(height: 20),
            Text(
              "Welcome, $_displayName",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              _displayRole.toUpperCase(),
              style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade700, fontWeight: FontWeight.bold, letterSpacing: 1.2),
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
                _buildStaffAction(Icons.list_alt, "View Queue", () {}),
                _buildStaffAction(Icons.person_add, "Register Patient", () {}),
                _buildStaffAction(Icons.calendar_today, "Appointments", () {}),
                _buildStaffAction(Icons.chat, "Messages", () {
                  // Navigate to Staff Messages
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StaffMessagesView()),
                  );
                }),
                // Only show Settings if admin
                if (widget.isAdmin == true)
                  _buildStaffAction(Icons.settings, "Settings", () {}),
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
          border: Border.all(color: Colors.blueGrey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blueGrey.shade800, size: 30),
            const SizedBox(height: 10),
            Text(
              label, 
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: Colors.blueGrey.shade900,
                fontSize: 13
              )
            ),
          ],
        ),
      ),
    );
  }
}