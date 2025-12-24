import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_sense_application/screens/patient/dashboard.dart';
import 'package:med_sense_application/main.dart';
import 'package:med_sense_application/utils/translations.dart';

class PinLoginView extends StatefulWidget {
  const PinLoginView({super.key});

  @override
  State<PinLoginView> createState() => _PinLoginViewState();
}

class _PinLoginViewState extends State<PinLoginView> {
  final _supabase = Supabase.instance.client;
  String _enteredPin = "";
  String? _storedPin;
  bool _isLoading = true;
  String _errorMessage = "";

  // Theme Colors
  final Color _primaryYellow = const Color(0xFFFBC02D);

  @override
  void initState() {
    super.initState();
    _loadStoredPin();
  }

  Future<void> _loadStoredPin() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final pin = prefs.getString('quick_pin_${user.id}');
      setState(() {
        _storedPin = pin;
        _isLoading = false;
      });
    } else {
      // Should not happen if logic in main.dart is correct, but safe fallback
      _handleLogout(); 
    }
  }

  void _onDigitPress(String digit) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = ""; // Clear error on new input
      });

      if (_enteredPin.length == 6) {
        _validatePin();
      }
    }
  }

  void _onDeletePress() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _validatePin() {
    if (_enteredPin == _storedPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    } else {
      setState(() {
        _enteredPin = "";
        _errorMessage = "Incorrect PIN. Please try again.";
      });
      // Optional: Add haptic feedback here
    }
  }

  Future<void> _handleLogout() async {
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _primaryYellow))
            : Stack(
                fit: StackFit.expand,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 50),
                      const Icon(Icons.lock_outline, size: 60, color: Colors.black87),
                      const SizedBox(height: 20),
                      Text(
                        AppTranslations.get('welcome_title'), // "Good to See You Again!"
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Enter your Quick Access PIN",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      const SizedBox(height: 40),

                      // PIN Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index < _enteredPin.length
                                  ? _primaryYellow
                                  : Colors.grey[300],
                            ),
                          );
                        }),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Error Message
                      if (_errorMessage.isNotEmpty)
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        )
                      else
                        const SizedBox(height: 20),

                      const Spacer(),

                      // Number Pad
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        child: Column(
                          children: [
                            _buildRow('1', '2', '3'),
                            const SizedBox(height: 20),
                            _buildRow('4', '5', '6'),
                            const SizedBox(height: 20),
                            _buildRow('7', '8', '9'),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: Center(
                                    child: TextButton(
                                      onPressed: _handleLogout,
                                      child: const Text(
                                        "Forgot?", 
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.grey, fontSize: 12) // Slightly smaller text to fit
                                      ),
                                    ),
                                  ),
                                ),
                                _buildDigitButton('0'),
                                SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: IconButton(
                                    onPressed: _onDeletePress,
                                    icon: const Icon(Icons.backspace_outlined, size: 28, color: Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                  Positioned(
                    top: 10,
                    right: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _handleLogout,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.withValues(alpha: 0.1),
                          ),
                          child: const Icon(Icons.close, size: 30, color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRow(String d1, String d2, String d3) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildDigitButton(d1),
        _buildDigitButton(d2),
        _buildDigitButton(d3),
      ],
    );
  }

  Widget _buildDigitButton(String digit) {
    return GestureDetector(
      onTap: () => _onDigitPress(digit),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[100],
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
  }
}