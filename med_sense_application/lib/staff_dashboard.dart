import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // To navigate back to main/home on logout

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  final _supabase = Supabase.instance.client;
  String _staffName = "Staff";

  @override
  void initState() {
    super.initState();
    _loadStaffProfile();
  }

  Future<void> _loadStaffProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _staffName = user.userMetadata?['full_name'] ?? "Staff";
      });
    }
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
              "Welcome, $_staffName",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Clinic Management Panel",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            // Placeholder for future staff features
            _buildStaffAction(Icons.list_alt, "View Queue"),
            const SizedBox(height: 15),
            _buildStaffAction(Icons.person_add, "Register Patient"),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffAction(IconData icon, String label) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blueGrey.shade800),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900)),
        ],
      ),
    );
  }
}