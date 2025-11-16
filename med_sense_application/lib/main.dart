import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://afdhbiquywcoykiltbnf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFmZGhiaXF1eXdjb3lraWx0Ym5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzMDk3ODMsImV4cCI6MjA3ODg4NTc4M30.VbTd-yMc7QszVJKtb9HJHtOHxSJyPwWOIvM5BCkfU8Q',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedSense',
      theme: ThemeData(
        // CHANGED: Updated seedColor to a yellow shade to match the design
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFBC02D)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Welcome'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // --- STATE & VARIABLES ---
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // --- LIFECYCLE METHODS ---
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- FUNCTIONS & LOGIC ---
  Future<void> _showAuthModal(bool isSignUp) async {
    // Reset form fields
    _formKey.currentState?.reset();
    _emailController.clear();
    _passwordController.clear();

    // Show the modal
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to grow and avoid keyboard
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        // Use padding to avoid the keyboard
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 30,
            right: 30,
          ),
          child: _buildAuthForm(isSignUp),
        );
      },
    );
  }

  Widget _buildAuthForm(bool isSignUp) {
    // Use StatefulBuilder to manage the loading state *inside* the modal
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min, // Take only needed space
            children: [
              Text(
                isSignUp ? 'Create Account' : 'Sign In',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              // Password Field
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    // Validate the form
                    if (_formKey.currentState!.validate()) {
                      setModalState(() {
                        _isLoading = true;
                      });

                      try {
                        if (isSignUp) {
                          // --- Create Account Logic ---
                          await _supabase.auth.signUp(
                            email: _emailController.text.trim(),
                            password: _passwordController.text.trim(),
                          );
                          // --- FIX: Use context.mounted ---
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Success! Check your email for confirmation.')),
                            );
                          }
                        } else {
                          // --- Login Logic ---
                          await _supabase.auth.signInWithPassword(
                            email: _emailController.text.trim(),
                            password: _passwordController.text.trim(),
                          );
                        }
                        // --- FIX: Use context.mounted ---
                        if (context.mounted) {
                          Navigator.of(context).pop(); // Close bottom sheet on success
                        }
                      } on AuthException catch (e) {
                        // --- FIX: Use context.mounted ---
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.message)),
                          );
                        }
                      } catch (e) {
                        // --- FIX: Use context.mounted ---
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('An unexpected error occurred')),
                          );
                        }
                      } finally {
                        // --- FIX: Use context.mounted ---
                        if (context.mounted) {
                          setModalState(() {
                            _isLoading = false;
                          });
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBC02D), // Use primary color
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : Text(isSignUp ? 'Sign Up' : 'Sign In', style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 30), // Space at the bottom
            ],
          ),
        );
      },
    );
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFFFBC02D);

    return Scaffold(
      backgroundColor: primaryColor,
      body: Stack(
        children: [
          // --- Top Header Content ---
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                // Padding for the header content
                padding: const EdgeInsets.only(top: 60.0, left: 40, right: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Take only needed space
                  children: [
                    const Text(
                      'MedSense',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Bottom Content Card ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              // use SingleChildScrollView to prevent overflow on small phones
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40), // Space from top of card

                      // --- Placeholder Image ---
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'images/Doctors-cuate.png',
                          width: 300,
                          height: 250,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- Subtitle Text ---
                      const Text(
                        'Hey there! Let\'s Keep',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'You Healthy',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // --- Create Account Button ---
                      SizedBox(
                        width: double.infinity,
                        height: 55, // Set button height
                        child: ElevatedButton(
                          onPressed: () {
                            _showAuthModal(true); // true = isSignUp
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 1,
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('Create Account',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // --- Login Button ---
                      SizedBox(
                        width: double.infinity,
                        height: 55, // Set button height
                        child: ElevatedButton(
                          onPressed: () {
                            _showAuthModal(false); // false = isSignIn
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('Login',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}