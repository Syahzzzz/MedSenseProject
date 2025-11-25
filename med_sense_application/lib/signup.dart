import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'translations.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController(); // For Date of Birth display
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  
  bool _agreeToTerms = false;
  bool _isOku = false;
  DateTime? _selectedDate; // To store the actual Date object

  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _lightYellowInput = const Color(0xFFFFF9C4);

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- DATE PICKER LOGIC ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000), // Default to year 2000
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryYellow,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // Format date as YYYY-MM-DD for display/storage
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // --- SHOW TERMS & CONDITIONS DIALOG ---
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppTranslations.get('terms_conditions'), style: const TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              child: Text(AppTranslations.get('close'), style: const TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _agreeToTerms = true;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryYellow, foregroundColor: Colors.white),
              child: Text(AppTranslations.get('i_agree')),
            )
          ],
        );
      },
    );
  }

  Widget _buildTermPoint(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  Future<void> _handleSignup() async {
    // --- VALIDATION ---
    if (_fullNameController.text.trim().isEmpty) {
      _showError("Please enter your full name");
      return;
    }
    if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) {
      _showError("Please enter a valid email");
      return;
    }
    if (_dobController.text.isEmpty) {
      _showError("Please select your date of birth");
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError("Passwords do not match");
      return;
    }
    if (!_agreeToTerms) {
      _showError('Please agree to the Terms & Conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Sign up with Supabase
      await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _fullNameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'dob': _dobController.text.trim(), // Save DOB to metadata
          'is_oku': _isOku,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Success! Please check your email to confirm.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); 
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Unexpected error occurred');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
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
      ),
      body: Column(
        children: [
          // --- Top Section: Illustration ---
          Expanded(
            flex: 2,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Image.asset(
                  'images/Signup.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.medical_services, size: 80, color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          
          // --- Bottom Section: Form ---
          Expanded(
            flex: 6,
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
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      AppTranslations.get('start_journey_title'),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(AppTranslations.get('start_journey_subtitle'), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 30),

                    // 1. Full Name
                    _buildCustomTextField(_fullNameController, AppTranslations.get('full_name'), false),
                    const SizedBox(height: 15),

                    // 2. Email
                    _buildCustomTextField(_emailController, AppTranslations.get('email'), false),
                    const SizedBox(height: 15),

                    // 3. Phone Number
                    _buildCustomTextField(_phoneController, AppTranslations.get('phone_number'), false, keyboardType: TextInputType.phone),
                    const SizedBox(height: 15),

                    // 4. Date of Birth (Clickable Field)
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer( // Prevents keyboard from opening
                        child: _buildCustomTextField(
                          _dobController, 
                          AppTranslations.get('select_birthday'), // Ensure this key exists or use "Date of Birth"
                          false,
                          icon: Icons.calendar_today_outlined
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 5. Password
                    _buildCustomTextField(_passwordController, AppTranslations.get('password'), true),
                    const SizedBox(height: 15),

                    // 6. Confirm Password
                    _buildCustomTextField(_confirmPasswordController, AppTranslations.get('confirm_pass'), true),
                    
                    const SizedBox(height: 20),

                    // --- CHECKBOX 1: Terms & Conditions (With Hyperlink) ---
                    _buildCheckboxRow(
                      value: _agreeToTerms,
                      onChanged: (val) => setState(() => _agreeToTerms = val ?? false),
                      labelWidget: RichText(
                        text: TextSpan(
                          text: AppTranslations.get('agree_to'),
                          style: TextStyle(fontSize: 12, color: Colors.grey[800], fontFamily: 'Arial'), 
                          children: [
                            TextSpan(
                              text: AppTranslations.get('terms_conditions'),
                              style: const TextStyle(
                                color: Colors.blue, 
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
                            ),
                            TextSpan(text: AppTranslations.get('and_privacy')),
                          ],
                        ),
                      ),
                    ),

                    // --- CHECKBOX 2: Disability (OKU) ---
                    _buildCheckboxRow(
                      value: _isOku,
                      onChanged: (val) => setState(() => _isOku = val ?? false),
                      labelWidget: Text(
                        AppTranslations.get('oku_checkbox'),
                        style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.2),
                      ),
                    ),

                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryYellow,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shadowColor: _primaryYellow.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(AppTranslations.get('signup'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(AppTranslations.get('already_have_account'), style: TextStyle(color: Colors.grey[600])),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                          },
                          child: Text(AppTranslations.get('login'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTextField(TextEditingController controller, String hint, bool obscure, {TextInputType? keyboardType, IconData? icon}) {
    return Container(
      decoration: BoxDecoration(color: _lightYellowInput, borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          // Optional icon (used for Date of Birth)
          suffixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        ),
      ),
    );
  }

  Widget _buildCheckboxRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required Widget labelWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: _primaryYellow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: labelWidget, 
          ),
        ],
      ),
    );
  }
}