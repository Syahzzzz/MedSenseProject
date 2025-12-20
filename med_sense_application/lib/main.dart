import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'translations.dart'; // Import translations
import 'language_selector_widget.dart'; // Import language widget
import 'login.dart';
import 'signup.dart';
import 'dashboard.dart';
import 'onboarding_view.dart';
import 'pin_login_view.dart'; // Import Pin Login
import 'staff_login_view.dart'; // Import Staff Login View

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://toqvutxnatkjxtpttjog.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRvcXZ1dHhuYXRranh0cHR0am9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0ODg1OTEsImV4cCI6MjA3OTA2NDU5MX0.D8bzPRlqXhPrc28fUFSw5GVPkPMwvRd-iUOECkrQbm0',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap MaterialApp in ValueListenableBuilder to listen for language changes
    return ValueListenableBuilder<String>(
      valueListenable: appLanguageNotifier,
      builder: (context, language, child) {
        return MaterialApp(
          // Adding key triggers a full rebuild when language changes
          key: ValueKey(language), 
          title: 'MedSense',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFBC02D),
            ),
            useMaterial3: true,
          ),
          home: const MyHomePage(),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _supabase = Supabase.instance.client;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _requestFilePermissions();
    _checkSession(); // Check for existing login on app start
  }

  // --- Auto-Login / Quick PIN Logic ---
  Future<void> _checkSession() async {
    // Artificial delay for splash effect (optional)
    await Future.delayed(const Duration(milliseconds: 1500));

    final session = _supabase.auth.currentSession;
    if (session != null) {
      // User is logged in, check if Quick PIN is enabled
      final prefs = await SharedPreferences.getInstance();
      final bool isPinEnabled = prefs.getBool('quick_pin_enabled') ?? false;
      
      // Also check if onboarding was seen (so we don't skip it if it wasn't)
      final user = session.user;
      final bool hasSeenOnboarding = prefs.getBool('has_seen_onboarding_${user.id}') ?? false;

      if (!mounted) return;

      if (isPinEnabled) {
        // Go to PIN Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PinLoginView()),
        );
      } else {
        // Go to Dashboard (or Onboarding)
        if (hasSeenOnboarding) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingView()),
          );
        }
      }
    } else {
      // Not logged in, stay on Landing Page
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  Future<void> _requestFilePermissions() async {
    // Check status for Storage (General)
    var storageStatus = await Permission.storage.status;
    
    // Check status for Photos/Videos (Android 13+)
    var photosStatus = await Permission.photos.status;

    if (!storageStatus.isGranted || !photosStatus.isGranted) {
      // Request multiple permissions at once to ensure coverage across Android versions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
      ].request();

      // Optional: Check result and show a snackbar if permanently denied
      if (statuses[Permission.storage] == PermissionStatus.permanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required. Please enable it in settings.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFFFBC02D);

    // If checking auth, show a simple loading/splash screen
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: primaryColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'MedSense',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: primaryColor,
      body: Stack(
        children: [
          // --- Top Header Content ---
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon with translucent background
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Styled Text
                    const Text(
                      'MedSense',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 4.0,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Language Button (Top Right) ---
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const LanguageAppBarButton(color: Colors.white),
                ),
              ),
            ),
          ),

          // --- Bottom Content Card ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // --- Image ---
                      SizedBox(
                        height: 250,
                        child: Image.asset(
                          'images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      // Using Translation for Slogan
                      Text(
                        AppTranslations.get('welcome_title'),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        AppTranslations.get('medsense_slogan'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // --- Create Account Button ---
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignupPage()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            AppTranslations.get('create_account'),
                            style: const TextStyle(
                              fontSize: 16, 
                              color: Colors.black, 
                              fontWeight: FontWeight.w700
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // --- Login Button ---
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: primaryColor.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            AppTranslations.get('login'),
                            style: const TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      const SizedBox(height: 10),

                      // --- Staff Login Link ---
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StaffLoginView(), 
                            ),
                          );
                        },
                        child: Text(
                          AppTranslations.get('login_staff'),
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
                            decoration: TextDecoration.underline,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}