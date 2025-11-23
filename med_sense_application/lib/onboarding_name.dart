import 'package:flutter/material.dart';
import 'onboarding_birthday.dart';

class OnboardingNamePage extends StatefulWidget {
  const OnboardingNamePage({super.key});

  @override
  State<OnboardingNamePage> createState() => _OnboardingNamePageState();
}

class _OnboardingNamePageState extends State<OnboardingNamePage> {
  final _nameController = TextEditingController();
  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _lightYellowInput = const Color(0xFFFFF9C4);

  void _nextPage() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your name")),
      );
      return;
    }
    // Navigate to Birthday Page, passing the name
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnboardingBirthdayPage(fullName: _nameController.text.trim()),
      ),
    );
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
                Container(width: 40, height: 8, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 8),
                Container(width: 40, height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4))),
              ],
            ),
            
            Expanded(
              flex: 4,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_pin_circle_rounded, size: 80, color: Colors.white),
                    const SizedBox(height: 20),
                    const Text(
                      "What should we call you?",
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
                      const Text("Your Name", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(color: _lightYellowInput, borderRadius: BorderRadius.circular(15)),
                        child: TextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: "e.g. John Doe",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(20),
                          ),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryYellow,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text("Next", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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