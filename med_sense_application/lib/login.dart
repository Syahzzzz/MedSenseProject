import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'signup.dart';
import 'forgot_password.dart';
import 'onboarding_name.dart';
import 'dashboard.dart';
import 'translations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  
  // --- Remember Me State ---
  bool _rememberMe = false;

  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _lightYellowInput = const Color(0xFFFFF9C4);

  @override
  void initState() {
    super.initState();
    // Check for saved credentials after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptAutoLogin();
    });
  }

  // --- Auto Login Logic ---
  Future<void> _attemptAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberStatus = prefs.getBool('remember_me_status') ?? false;

    if (rememberStatus) {
      final savedEmail = prefs.getString('remember_me_email');
      final savedPassword = prefs.getString('remember_me_password');

      if (savedEmail != null && savedPassword != null) {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
          _rememberMe = true;
        });

        // Trigger login automatically
        _handleLogin(); 
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // --- Save/Remove Credentials based on Remember Me ---
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('remember_me_email', _emailController.text.trim());
        await prefs.setString('remember_me_password', _passwordController.text.trim());
        await prefs.setBool('remember_me_status', true);
      } else {
        await prefs.remove('remember_me_email');
        await prefs.remove('remember_me_password');
        await prefs.setBool('remember_me_status', false);
      }

      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        final user = response.user;
        final metaData = user?.userMetadata;
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          if (metaData == null || metaData['full_name'] == null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OnboardingNamePage()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardPage()),
            );
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unexpected error occurred'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryYellow,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Image.asset(
                  'images/Login.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.medical_services_outlined, size: 80, color: Colors.white
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                child: Column(
                  children: [
                    Text(AppTranslations.get('welcome_title'),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(AppTranslations.get('welcome_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 40),
                    
                    _buildCustomTextField(_emailController, AppTranslations.get('email'), false),
                    const SizedBox(height: 20),
                    _buildCustomTextField(_passwordController, AppTranslations.get('password'), true),
                    
                    const SizedBox(height: 10),

                    // --- Remember Me & Forgot Password Row ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Remember Me Checkbox
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: _primaryYellow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppTranslations.get('remember_me'),
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),

                        // Forgot Password Link
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                          child: Text(AppTranslations.get('forgot_pass'), style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryYellow,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shadowColor: _primaryYellow.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(AppTranslations.get('login'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(AppTranslations.get('no_account'), style: TextStyle(color: Colors.grey[600])),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignupPage())),
                          child: Text(AppTranslations.get('signup'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTextField(TextEditingController controller, String hint, bool obscure) {
    return Container(
      decoration: BoxDecoration(color: _lightYellowInput, borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}