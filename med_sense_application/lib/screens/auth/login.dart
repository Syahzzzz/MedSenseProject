import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:med_sense_application/screens/auth/signup.dart';
import 'package:med_sense_application/screens/auth/forgot_password.dart';
import 'package:med_sense_application/screens/patient/dashboard.dart';
import 'package:med_sense_application/screens/auth/onboarding_view.dart';
import 'package:med_sense_application/utils/translations.dart';
import 'package:med_sense_application/widgets/language_selector_widget.dart'; 

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
  bool _obscurePassword = true; 
  String? _storedPin;

  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _lightYellowInput = const Color(0xFFFFF9C4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedCredentials();
    });
  }

  // --- Load Credentials & Check for PIN ---
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberStatus = prefs.getBool('remember_me_status') ?? false;

    if (rememberStatus) {
      final savedEmail = prefs.getString('remember_me_email');
      final savedPassword = prefs.getString('remember_me_password');
      final savedUid = prefs.getString('remember_me_uid');
      final bool pinEnabled = prefs.getBool('quick_pin_enabled') ?? false;

      if (savedEmail != null && savedPassword != null) {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
          _rememberMe = true;
        });

        // --- PIN CHECK ---
        if (pinEnabled && savedUid != null) {
          final String? storedPin = prefs.getString('quick_pin_$savedUid');
          if (storedPin != null && storedPin.isNotEmpty && mounted) {
            // Show PIN Dialog immediately
            setState(() {
              _storedPin = storedPin;
            });
            _showPinDialog(storedPin, savedEmail, savedPassword);
          }
        }
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
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = response.user;
      
      // --- Save/Remove Credentials (Moved after successful login) ---
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe && user != null) {
        await prefs.setString('remember_me_email', _emailController.text.trim());
        await prefs.setString('remember_me_password', _passwordController.text.trim());
        await prefs.setString('remember_me_uid', user.id); // Save UID for PIN retrieval
        await prefs.setBool('remember_me_status', true);
      } else {
        await prefs.remove('remember_me_email');
        await prefs.remove('remember_me_password');
        await prefs.remove('remember_me_uid');
        await prefs.setBool('remember_me_status', false);
      }

      if (user != null) {
        final String onboardingKey = 'has_seen_onboarding_${user.id}';
        final bool hasSeenOnboarding = prefs.getBool(onboardingKey) ?? false;

        if (mounted) {
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
      }
      
    } on AuthException catch (e) {
      if (mounted) {
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

  // --- Quick PIN Dialog Logic ---
  void _showPinDialog(String correctPin, String email, String password) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // Prevent dismissing by tapping outside to enforce security logic
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return _PinEntryWidget(
          correctPin: correctPin,
          onSuccess: () {
            Navigator.pop(context); // Close dialog
            _handleLogin(); // Trigger existing login flow which uses the pre-filled controllers
          },
        );
      },
    );
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
        actions: const [
          LanguageAppBarButton(color: Colors.white),
          SizedBox(width: 12),
        ],
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

                    if (_storedPin != null) ...[
                      const SizedBox(height: 15),
                      TextButton.icon(
                        onPressed: () {
                           if (_storedPin != null) {
                              _showPinDialog(_storedPin!, _emailController.text, _passwordController.text);
                           }
                        },
                        icon: const Icon(Icons.dialpad, size: 20),
                        label: const Text("Enter Quick PIN"),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                        ),
                      ),
                    ],

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
          
          prefixIcon: isPassword
              ? const SizedBox(width: 48, height: 48)
              : null,

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

// --- Local Widget for PIN Entry inside Dialog ---
class _PinEntryWidget extends StatefulWidget {
  final String correctPin;
  final VoidCallback onSuccess;

  const _PinEntryWidget({required this.correctPin, required this.onSuccess});

  @override
  State<_PinEntryWidget> createState() => _PinEntryWidgetState();
}

class _PinEntryWidgetState extends State<_PinEntryWidget> {
  String _enteredPin = "";
  String _message = "Enter your Quick Access PIN";
  Color _messageColor = Colors.grey;
  
  // --- Brute Force Protection State ---
  int _failedAttempts = 0;
  final int _maxAttempts = 5;
  final int _warningThreshold = 2; // Show attempts left after 2 wrong tries

  void _onDigitPress(String digit) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += digit;
        // Only reset message if we aren't already in warning mode
        if (_failedAttempts < _warningThreshold) {
          _message = "Enter your Quick Access PIN";
          _messageColor = Colors.grey;
        }
      });

      if (_enteredPin.length == 6) {
        _validatePin();
      }
    }
  }

  void _validatePin() {
    if (_enteredPin == widget.correctPin) {
      widget.onSuccess();
    } else {
      _handleFailedAttempt();
    }
  }

  void _handleFailedAttempt() {
    setState(() {
      _failedAttempts++;
      _enteredPin = ""; // Clear input
      
      if (_failedAttempts >= _maxAttempts) {
        // Too many attempts - Force password login
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Too many failed attempts. Please login with password."),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else if (_failedAttempts >= _warningThreshold) {
        // Show remaining attempts
        int attemptsLeft = _maxAttempts - _failedAttempts;
        _message = "Incorrect PIN. $attemptsLeft attempts remaining.";
        _messageColor = Colors.red;
      } else {
        // Just incorrect
        _message = "Incorrect PIN. Try again.";
        _messageColor = Colors.red;
      }
    });
  }

  void _onDeletePress() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Standard size for number buttons to ensure alignment
    const double buttonSize = 70.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Icon(Icons.lock_open_rounded, size: 50, color: Color(0xFFFBC02D)),
          const SizedBox(height: 20),
          Text(
            AppTranslations.get('welcome_title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_message, style: TextStyle(color: _messageColor, fontSize: 14, fontWeight: FontWeight.w500)),
          
          const SizedBox(height: 30),
          
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < _enteredPin.length ? const Color(0xFFFBC02D) : Colors.grey[200],
              ),
            )),
          ),

          const Spacer(),

          // Numpad
          Column(
            children: [
              _buildRow('1', '2', '3'),
              const SizedBox(height: 20),
              _buildRow('4', '5', '6'),
              const SizedBox(height: 20),
              _buildRow('7', '8', '9'),
              const SizedBox(height: 20),
              // Bottom Row with Centered '0'
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Side: "Use Password" text, wrapped in container of same size as buttons
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text("Use\nPass", 
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12)
                        ),
                      ),
                    ),
                  ),
                  
                  // Center: '0' Button
                  _buildBtn('0'),
                  
                  // Right Side: Backspace, wrapped in container of same size
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: IconButton(
                      onPressed: _onDeletePress,
                      icon: const Icon(Icons.backspace_outlined, size: 28),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRow(String a, String b, String c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [_buildBtn(a), _buildBtn(b), _buildBtn(c)],
    );
  }

  Widget _buildBtn(String text) {
    return GestureDetector(
      onTap: () => _onDigitPress(text),
      child: Container(
        width: 70, height: 70,
        decoration: BoxDecoration(color: Colors.grey[50], shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }
}