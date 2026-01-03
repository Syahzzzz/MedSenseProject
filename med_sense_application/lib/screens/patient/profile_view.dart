import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:med_sense_application/main.dart';
import 'package:med_sense_application/screens/patient/edit_profile_view.dart';
import 'package:med_sense_application/screens/auth/change_password_view.dart';
import 'package:med_sense_application/utils/translations.dart';
import 'package:med_sense_application/widgets/language_selector_widget.dart';
import 'package:med_sense_application/screens/payment/add_card_view.dart'; 
import 'package:med_sense_application/services/tts_manager.dart'; // Import TTS Manager

class ProfileView extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(bool)? onOkuChanged;

  const ProfileView({
    super.key, 
    this.onBack,
    this.onOkuChanged
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  // --- State Variables ---
  final _supabase = Supabase.instance.client;
  final TtsManager _tts = TtsManager(); // Initialize TTS
  
  String _userName = "User";
  String _email = "";
  String? _avatarUrl;
  String _patientId = "--------"; 
  bool _notificationsEnabled = false;
  bool _isOkuEnabled = false; // OKU toggle state
  bool _isQuickPinEnabled = false; // Quick PIN toggle state

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _tts.init(); // Initialize TTS engine
    _loadUserProfile();
    _loadLocalSettings(); 
  }

  // --- Data Loading ---
  Future<void> _loadUserProfile() async {
    try {
        await _supabase.auth.refreshSession();
    } catch (_) {}

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase
            .from('Patient')
            .select()
            .eq('patient_id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _email = user.email ?? "";
            
            String? url = user.userMetadata?['avatar_url'];
            if (url != null) {
            _avatarUrl = "$url?t=${DateTime.now().millisecondsSinceEpoch}";
            }

            if (data != null) {
              _userName = data['name'] ?? "User";
              
              String rawId = data['patient_id'].toString();
              if (rawId.length >= 8) {
                _patientId = rawId.substring(0, 8).toUpperCase();
              } else {
                _patientId = rawId;
              }
            } else {
              _userName = user.userMetadata?['full_name'] ?? "User";
              if (user.id.length >= 8) {
                _patientId = user.id.substring(0, 8).toUpperCase();
              }
            }
          });
        }
      } catch (e) {
        debugPrint("Error loading profile from DB: $e");
      }
    }
  }

  Future<void> _loadLocalSettings() async {
    final status = await Permission.notification.status;
    final prefs = await SharedPreferences.getInstance();
    
    // Load local preferences
    final okuStatus = prefs.getBool('is_oku_enabled') ?? false;
    final pinStatus = prefs.getBool('quick_pin_enabled') ?? false;

    if (mounted) {
      setState(() {
        _notificationsEnabled = status.isGranted;
        _isOkuEnabled = okuStatus;
        _isQuickPinEnabled = pinStatus;
      });
      _tts.setEnabled(_isOkuEnabled); // Sync TTS state
    }
  }

  // --- Actions ---
  Future<void> _toggleNotifications(bool value) async {
    // Speak action
    _tts.speak(value ? "Notifications enabled" : "Notifications disabled");

    if (value) {
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
      setState(() => _notificationsEnabled = false);
    }
  }

  Future<void> _toggleOku(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_oku_enabled', value);
    
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('Patient').update({'is_oku': value}).eq('patient_id', user.id);
      } catch (e) {
        debugPrint("Failed to sync OKU status to DB: $e");
      }
    }

    setState(() {
      _isOkuEnabled = value;
    });
    
    // Update TTS Manager state immediately
    _tts.setEnabled(value);
    _tts.speak(value ? "OKU Mode Enabled. Text to speech active." : "OKU Mode Disabled");

    // Notify Parent
    if (widget.onOkuChanged != null) {
      widget.onOkuChanged!(value);
    }
  }

  Future<void> _toggleQuickPin(bool value) async {
    _tts.speak(value ? "Quick PIN enabled" : "Quick PIN disabled");

    final prefs = await SharedPreferences.getInstance();
    final user = _supabase.auth.currentUser;

    if (value && user != null) {
      final savedPin = prefs.getString('quick_pin_${user.id}');
      if (savedPin == null || savedPin.isEmpty) {
        if (mounted) {
          _tts.speak("No PIN set. Please set up a PIN in Security settings first.");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No PIN set. Please set up a PIN in Security settings first."),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }
    }

    await prefs.setBool('quick_pin_enabled', value);
    setState(() {
      _isQuickPinEnabled = value;
    });
  }

  // --- TTS Helper ---
  void _speakText(String text) {
    if (_isOkuEnabled) {
      _tts.speak(text);
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

  void _showTermsAndConditions() {
    _speakText("Opening Terms and Conditions");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppTranslations.get('terms_conditions'), 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTermPoint("1. ${AppTranslations.get('tc_1_title')}", AppTranslations.get('tc_1_content')),
              _buildTermPoint("2. ${AppTranslations.get('tc_2_title')}", AppTranslations.get('tc_2_content')),
              _buildTermPoint("3. ${AppTranslations.get('tc_3_title')}", AppTranslations.get('tc_3_content')),
              _buildTermPoint("4. ${AppTranslations.get('tc_4_title')}", AppTranslations.get('tc_4_content')),
              _buildTermPoint("5. ${AppTranslations.get('tc_5_title')}", AppTranslations.get('tc_5_content')),
              _buildTermPoint("6. ${AppTranslations.get('tc_6_title')}", AppTranslations.get('tc_6_content')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppTranslations.get('close'), 
              style: const TextStyle(color: Color(0xFFFBC02D), fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermPoint(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GestureDetector( // Make terms tappable for reading
        onTap: () => _speakText("$title. $content"),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              content,
              style: TextStyle(
                fontSize: 13, 
                color: Colors.grey[700],
                height: 1.4, 
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    _speakText("Are you sure you want to log out?");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('logout'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Are you sure you want to log out?"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.orange.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "This will reset your 'Remember Me' preferences. You will need to enter your email and password next time.",
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _performLogout(); // Execute logout
            },
            child: Text(AppTranslations.get('logout'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Explicitly remove remember me credentials
    await prefs.remove('remember_me_email');
    await prefs.remove('remember_me_password');
    await prefs.setBool('remember_me_status', false);
    
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
            if (widget.onBack != null) ...[
              GestureDetector(
                onTap: widget.onBack,
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back, size: 28, color: Colors.black),
                    SizedBox(width: 10),
                    Text("Back", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            GestureDetector(
              onTap: () => _speakText(AppTranslations.get('profile_title')),
              child: Text(
                AppTranslations.get('profile_title'),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),

            // Profile Header
            Center(
              child: GestureDetector(
                onTap: () => _speakText("Profile for $_userName. Email: $_email"),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFFBC02D),
                      backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? NetworkImage(_avatarUrl!)
                          : null,
                      child: _avatarUrl == null || _avatarUrl!.isEmpty
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 15),
                    
                    Text(
                      _userName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    
                    Text(
                      _email,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    
                    const SizedBox(height: 12),
                    // Patient ID Canvas
                    SizedBox(
                      width: 200, 
                      height: 36,
                      child: CustomPaint(
                        painter: PatientIdPainter(patientId: _patientId),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            _buildMenuTile(
              icon: Icons.person_outline,
              title: AppTranslations.get('personal_info'),
              onTap: () async {
                _speakText("Opening Personal Information");
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileView()),
                );
                await _loadUserProfile();
              },
            ),

            _buildMenuTile(
              icon: Icons.lock_outline,
              title: AppTranslations.get('security'),
              onTap: () {
                _speakText("Opening Security Settings");
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChangePasswordView()),
                );
              },
            ),

            // Payment Methods Menu Item
            _buildMenuTile(
              icon: Icons.payment,
              title: AppTranslations.get('payment_methods'),
              onTap: () {
                _speakText("Opening Payment Methods");
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddCardView()),
                );
              },
            ),

            const Divider(height: 30),

            // --- OKU Toggle ---
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: const Color(0xFFFBC02D),
              title: GestureDetector(
                onTap: () => _speakText("OKU Feature. Toggle to enable accessibility features."),
                child: Text(
                  AppTranslations.get('oku_feature'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              subtitle: Text(
                "Enable accessibility features",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              value: _isOkuEnabled,
              onChanged: _toggleOku,
            ),

            // --- Quick PIN Toggle (New) ---
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: const Color(0xFFFBC02D),
              title: GestureDetector(
                onTap: () => _speakText("Quick PIN. Toggle to enable quick login with PIN."),
                child: Text(
                  AppTranslations.get('tab_pin'), 
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              subtitle: Text(
                "Enable quick login with PIN",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              value: _isQuickPinEnabled,
              onChanged: _toggleQuickPin,
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: const Color(0xFFFBC02D),
              title: GestureDetector(
                onTap: () => _speakText("Notifications. Toggle to receive updates."),
                child: Text(
                  AppTranslations.get('notifications'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),

            const LanguageSelectorWidget(),

            const SizedBox(height: 40),

            // Logout Button with Confirmation
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _showLogoutConfirmation, 
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
            Center(
              child: GestureDetector(
                onTap: _showTermsAndConditions,
                child: Text(
                  AppTranslations.get('terms_conditions'),
                  style: TextStyle(
                    color: Colors.grey[600],
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                onTap: () => _speakText("Version 1.0.0"),
                child: Text(
                  "Version 1.0.0",
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

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

class PatientIdPainter extends CustomPainter {
  final String patientId;
  final Color backgroundColor;
  final Color borderColor;

  PatientIdPainter({
    required this.patientId,
    this.backgroundColor = const Color(0xFFFFF9C4), 
    this.borderColor = const Color(0xFFFBC02D),     
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.height / 2),
    );

    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, borderPaint);

    final textSpan = TextSpan(
      text: "ID : $patientId",
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(
      minWidth: 0,
      maxWidth: size.width,
    );

    final xCenter = (size.width - textPainter.width) / 2;
    final yCenter = (size.height - textPainter.height) / 2;
    
    textPainter.paint(canvas, Offset(xCenter, yCenter));
  }

  @override
  bool shouldRepaint(covariant PatientIdPainter oldDelegate) {
    return oldDelegate.patientId != patientId;
  }
}