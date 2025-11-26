import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added import
import 'dashboard.dart';
import 'translations.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // List of pages data
  final List<Map<String, String>> _pages = [
    {
      'image': 'images/logo.png',
      'titleKey': 'onboarding_1_title',
      'descKey': 'onboarding_1_desc',
    },
    {
      'image': 'images/Login.png',
      'titleKey': 'onboarding_2_title',
      'descKey': 'onboarding_2_desc',
    },
    {
      'image': 'images/Doctors-cuate.png',
      'titleKey': 'onboarding_3_title',
      'descKey': 'onboarding_3_desc',
    },
  ];

  Future<void> _finishOnboarding() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    // --- LOGIC UPDATED: User-Specific Key ---
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding_${user.id}', true);
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryYellow = const Color(0xFFFBC02D);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- Skip Button ---
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: Text(
                  AppTranslations.get('skip'),
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ),

            // --- Page View ---
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Image
                        SizedBox(
                          height: 300,
                          child: Image.asset(
                            _pages[index]['image']!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.image, size: 100, color: primaryYellow);
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // Title
                        Text(
                          AppTranslations.get(_pages[index]['titleKey']!),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Description
                        Text(
                          AppTranslations.get(_pages[index]['descKey']!),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // --- Bottom Indicators and Buttons ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Dots Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? primaryYellow : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Next / Get Started Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _finishOnboarding();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryYellow,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? AppTranslations.get('get_started')
                            : AppTranslations.get('next'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
}