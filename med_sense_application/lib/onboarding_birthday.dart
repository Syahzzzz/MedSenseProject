import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard.dart';

class OnboardingBirthdayPage extends StatefulWidget {
  final String fullName;
  const OnboardingBirthdayPage({super.key, required this.fullName});

  @override
  State<OnboardingBirthdayPage> createState() => _OnboardingBirthdayPageState();
}

class _OnboardingBirthdayPageState extends State<OnboardingBirthdayPage> {
  DateTime? _selectedDate;
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;
  
  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _lightYellowInput = const Color(0xFFFFF9C4);

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
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
      });
    }
  }

  Future<void> _finishSetup() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your birthday")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update User Metadata in Supabase
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': widget.fullName,
            'birthday': _selectedDate!.toIso8601String(),
            'profile_completed': true,
          },
        ),
      );

      if (mounted) {
        // Navigate to Dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
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
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Progress Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 40, height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.4), borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 8),
                Container(width: 40, height: 8, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              ],
            ),
            
            Expanded(
              flex: 4,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cake_rounded, size: 80, color: Colors.white),
                    const SizedBox(height: 20),
                    const Text(
                      "When is your birthday?",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
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
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      const Text("Date of Birth", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      
                      // Date Selector Button
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(color: _lightYellowInput, borderRadius: BorderRadius.circular(15)),
                          child: Text(
                            _selectedDate == null 
                                ? "Select Date" 
                                : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: _selectedDate == null ? Colors.grey : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _finishSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryYellow,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Finish & Go to Dashboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}