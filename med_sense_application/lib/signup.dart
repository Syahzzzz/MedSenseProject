import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // Import for TapGestureRecognizer
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  
  bool _agreeToTerms = false;
  bool _isOku = false;

  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _lightYellowInput = const Color(0xFFFFF9C4);

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- SHOW TERMS & CONDITIONS DIALOG ---
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Terms & Conditions"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTermPoint("1. Acceptance of Terms", 
                  "By creating an account on MedSense, you agree to comply with and be bound by these Terms and Conditions."),
                
                _buildTermPoint("2. Medical Disclaimer", 
                  "MedSense is an appointment booking platform. We do not provide medical advice, diagnosis, or treatment. In case of a medical emergency, please contact your local emergency services immediately."),
                
                _buildTermPoint("3. Appointments & Cancellations", 
                  "Appointments are subject to doctor availability. Cancellations or rescheduling must be made at least 24 hours in advance to avoid penalties or account suspension."),
                
                _buildTermPoint("4. Data Privacy", 
                  "We value your privacy. Your personal and medical data is stored securely and processed in accordance with the Personal Data Protection Act (PDPA). We do not share your health records without your consent."),
                
                _buildTermPoint("5. User Responsibilities", 
                  "You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account."),
                
                _buildTermPoint("6. Payment & Pricing", 
                  "Prices listed for services (e.g., Braces, Scaling) are estimates. Final pricing is determined by the clinic based on the actual treatment required."),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _agreeToTerms = true;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryYellow, foregroundColor: Colors.white),
              child: const Text("I Agree"),
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
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms & Conditions')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'phone_number': _phoneController.text.trim(),
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
                    const Text(
                      'Start Your Smile Journey',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text('A healthy smile starts with a simple sign up', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 30),

                    _buildCustomTextField(_emailController, 'Email', false),
                    const SizedBox(height: 15),
                    _buildCustomTextField(_phoneController, 'Phone Number', false, keyboardType: TextInputType.phone),
                    const SizedBox(height: 15),
                    _buildCustomTextField(_passwordController, 'Password', true),
                    
                    const SizedBox(height: 20),

                    // --- CHECKBOX 1: Terms & Conditions (With Hyperlink) ---
                    _buildCheckboxRow(
                      value: _agreeToTerms,
                      onChanged: (val) => setState(() => _agreeToTerms = val ?? false),
                      labelWidget: RichText(
                        text: TextSpan(
                          text: 'I agree to the ',
                          style: TextStyle(fontSize: 12, color: Colors.grey[800], fontFamily: 'Arial'), // Default text style
                          children: [
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: const TextStyle(
                                color: Colors.blue, 
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              // Make it clickable
                              recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
                            ),
                            const TextSpan(text: ' and Privacy Policy'),
                          ],
                        ),
                      ),
                    ),

                    // --- CHECKBOX 2: Disability (OKU) ---
                    _buildCheckboxRow(
                      value: _isOku,
                      onChanged: (val) => setState(() => _isOku = val ?? false),
                      labelWidget: Text(
                        'I am a person with disability (OKU). Enable accessibility features',
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
                            : const Text('Sign Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account? ', style: TextStyle(color: Colors.grey[600])),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                          },
                          child: const Text('Log In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  Widget _buildCustomTextField(TextEditingController controller, String hint, bool obscure, {TextInputType? keyboardType}) {
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
          hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  // Updated to accept a generic Widget for the label
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
            child: labelWidget, // Use the widget passed in
          ),
        ],
      ),
    );
  }
}