import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'signup.dart';
import 'forgot_password.dart';
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
  
  // --- State Variables ---
  bool _rememberMe = false;
  bool _obscurePassword = true; // Controls the eye icon

  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _lightYellowInput = const Color(0xFFFFF9C4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedCredentials();
    });
  }

  // --- Load Credentials (Don't Auto Login) ---
  Future<void> _loadSavedCredentials() async {
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
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter email and password')),
        );
        return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // --- Save/Remove Credentials ---
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

      // ignore: unused_local_variable
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // --- LOGIC UPDATED HERE: Removed Onboarding Check ---
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      }
      
    } on AuthException catch (e) {
      if (mounted) {
        // Better error message handling
        String msg = e.message;
        if (msg.contains("Invalid login credentials")) {
          msg = "Invalid email or password. If you just signed up, please check your email to verify your account.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
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
                    
                    // Email Field
                    _buildCustomTextField(
                      controller: _emailController, 
                      hint: AppTranslations.get('email'), 
                      obscure: false
                    ),
                    const SizedBox(height: 20),
                    
                    // Password Field with Eye Toggle
                    _buildCustomTextField(
                      controller: _passwordController, 
                      hint: AppTranslations.get('password'), 
                      obscure: _obscurePassword,
                      isPassword: true,
                      onEyePressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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

  Widget _buildCustomTextField({
    required TextEditingController controller, 
    required String hint, 
    required bool obscure, 
    bool isPassword = false,
    VoidCallback? onEyePressed
  }) {
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
          // Eye Icon Logic
          suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: onEyePressed,
              )
            : null,
        ),
      ),
    );
  }
}