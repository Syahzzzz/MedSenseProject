import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for input formatters
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added for PIN
import 'translations.dart'; // Added for translations

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  // Theme Color
  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _lightYellowInput = const Color(0xFFFFF9C4);

  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  // --- Password Tab Controllers ---
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  
  bool _obscureCurrentPass = true;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  // --- PIN Tab Controllers ---
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  // --- Password Logic ---
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _changePassword() async {
    if (_newPassController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }
    
    if (_newPassController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) throw "User not logged in";

      // Verify current password by signing in
      await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: _currentPassController.text.trim(),
      );

      final newPassword = _newPassController.text.trim();

      // Update Supabase Auth
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // Update custom table (if used for hashing logic on other platforms)
      await _supabase.from('Patient').update({
        'password_hash': _hashPassword(newPassword),
      }).eq('patient_id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
        );
        // Clear fields
        _currentPassController.clear();
        _newPassController.clear();
        _confirmPassController.clear();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update password. Check current password.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- PIN Logic ---
  Future<void> _savePin() async {
    final pin = _pinController.text;
    final confirmPin = _confirmPinController.text;

    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be 6 digits')),
      );
      return;
    }

    if (pin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('pin_mismatch'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        // Save the PIN locally mapped to user ID for "fast login" simulation
        await prefs.setString('quick_pin_${user.id}', pin);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppTranslations.get('pin_saved')),
              backgroundColor: Colors.green,
            ),
          );
          // Clear PIN fields
          _pinController.clear();
          _confirmPinController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PIN: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(AppTranslations.get('security_settings'), style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          bottom: TabBar(
            labelColor: _primaryYellow,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _primaryYellow,
            tabs: [
              Tab(text: AppTranslations.get('tab_password')),
              Tab(text: AppTranslations.get('tab_pin')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- TAB 1: Password ---
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppTranslations.get('current_pass'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildPasswordField(
                    _currentPassController, 
                    AppTranslations.get('enter_current_pass'),
                    _obscureCurrentPass,
                    () => setState(() => _obscureCurrentPass = !_obscureCurrentPass),
                  ),

                  const SizedBox(height: 20),

                  Text(AppTranslations.get('new_pass'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildPasswordField(
                    _newPassController, 
                    AppTranslations.get('enter_new_pass'),
                    _obscureNewPass,
                    () => setState(() => _obscureNewPass = !_obscureNewPass),
                  ),

                  const SizedBox(height: 20),

                  Text(AppTranslations.get('confirm_pass'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildPasswordField(
                    _confirmPassController, 
                    AppTranslations.get('reenter_new_pass'),
                    _obscureConfirmPass,
                    () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryYellow,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(AppTranslations.get('update_password'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            // --- TAB 2: Quick PIN ---
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    AppTranslations.get('pin_desc'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 30),

                  // Enter PIN
                  Text(AppTranslations.get('enter_pin'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildPinInput(_pinController),

                  const SizedBox(height: 20),

                  // Confirm PIN
                  Text(AppTranslations.get('confirm_pin_label'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildPinInput(_confirmPinController),

                  const SizedBox(height: 40),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _savePin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryYellow,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(AppTranslations.get('save_changes'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String hint, bool obscure, VoidCallback onToggle) {
    return Container(
      decoration: BoxDecoration(
        color: _lightYellowInput,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }

  Widget _buildPinInput(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: _lightYellowInput,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}