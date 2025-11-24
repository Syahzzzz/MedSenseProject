import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart';
import 'edit_profile_view.dart';
import 'change_password_view.dart';
import 'translations.dart';
import 'language_selector_widget.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  // --- State Variables ---
  final _supabase = Supabase.instance.client;
  String _userName = "User";
  String _email = "";
  bool _notificationsEnabled = false;

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkNotificationStatus();
  }

  // --- Data Loading ---
  void _loadUserProfile() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _email = user.email ?? "";
        _userName = user.userMetadata?['full_name'] ?? "User";
      });
    }
  }

  Future<void> _checkNotificationStatus() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() => _notificationsEnabled = status.isGranted);
    }
  }

  // --- Actions ---
  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Request Permission
      final status = await Permission.notification.request();
      if (!mounted) return;

      if (status.isGranted) {
        setState(() => _notificationsEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notifications Enabled"), backgroundColor: Colors.green),
        );
      } else if (status.isPermanentlyDenied) {
        setState(() => _notificationsEnabled = false);
        _showSettingsDialog();
      } else {
        setState(() => _notificationsEnabled = false);
      }
    } else {
      // Turn Off
      setState(() => _notificationsEnabled = false);
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('permission_required')),
        content: Text(AppTranslations.get('permission_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: Text(AppTranslations.get('open_settings'), style: const TextStyle(color: Color(0xFFFBC02D))),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    // Clear local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // Sign out Supabase
    await _supabase.auth.signOut();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MyHomePage()),
        (route) => false,
      );
    }
  }

  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              AppTranslations.get('profile_title'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFFBC02D),
                    child: const Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _userName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _email,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Menu Items
            _buildMenuTile(
              icon: Icons.person_outline,
              title: AppTranslations.get('personal_info'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileView()),
                ).then((_) => _loadUserProfile());
              },
            ),

            _buildMenuTile(
              icon: Icons.lock_outline,
              title: AppTranslations.get('security'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChangePasswordView()),
                );
              },
            ),

            const Divider(height: 30),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: const Color(0xFFFBC02D),
              title: Text(
                AppTranslations.get('notifications'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),

            // REPLACED OLD LANGUAGE TILE WITH NEW WIDGET
            const LanguageSelectorWidget(),

            const SizedBox(height: 40),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _handleLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout),
                    const SizedBox(width: 10),
                    Text(
                      AppTranslations.get('logout'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper Widget for Menu Items
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9C4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.black87),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}