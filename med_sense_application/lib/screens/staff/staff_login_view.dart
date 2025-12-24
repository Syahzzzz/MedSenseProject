import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import Shared Preferences
import 'package:med_sense_application/screens/staff/staff_dashboard.dart';

class StaffLoginView extends StatefulWidget {
  final String? branchName;

  const StaffLoginView({super.key, this.branchName});

  @override
  State<StaffLoginView> createState() => _StaffLoginViewState();
}

class _StaffLoginViewState extends State<StaffLoginView> {
  bool _isLoading = false;
  bool _rememberMe = false; // State for checkbox
  
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadUserCredentials(); // Load saved credentials on start
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Load saved credentials
  Future<void> _loadUserCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _rememberMe = prefs.getBool('staff_remember_me') ?? false;
        if (_rememberMe) {
          _emailController.text = prefs.getString('staff_email') ?? '';
          _passwordController.text = prefs.getString('staff_password') ?? '';
        }
      });
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Email and Password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call the custom Postgres RPC function 'login_staff'
      final response = await _supabase.rpc(
        'login_staff', 
        params: {
          'email_input': email, 
          'password_input': password
        }
      );

      // Log response for debugging
      debugPrint("Login Response: $response");

      if (response != null && response['success'] == true) {
        final staffData = response['data'];
        
        // CRITICAL FIX: Actually sign in to Supabase Auth to establish a session
        try {
          await _supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } catch (authError) {
          debugPrint("Supabase Auth Error (ignoring since RPC passed): $authError");
          // Proceed anyway as RPC confirmed credentials, but session might be weak
        }

        // Handle "Remember Me" logic
        final prefs = await SharedPreferences.getInstance();
        
        // Save Staff ID persistently
        await prefs.setString('current_staff_id', staffData['staff_id']);

        if (_rememberMe) {
          await prefs.setBool('staff_remember_me', true);
          await prefs.setString('staff_email', email);
          await prefs.setString('staff_password', password); // Note: Storing password in plain prefs is not recommended for high security apps
        } else {
          await prefs.remove('staff_remember_me');
          await prefs.remove('staff_email');
          await prefs.remove('staff_password');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Login Successful"), backgroundColor: Colors.green),
          );

          // Navigate to Dashboard with staff details
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => StaffDashboard(
                staffName: staffData['name'],
                staffRole: staffData['role'],
                isAdmin: staffData['is_admin'],
              ),
            ),
          );
        }
      } else {
        // Login Failed
        final message = response != null ? response['message'] : "Unknown error";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Login Failed: $message"), backgroundColor: Colors.red),
          );
        }
      }
    } on PostgrestException catch (e) {
      // Handle Database errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Database Error: ${e.message}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Handle generic errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or Icon
              Image.asset(
                'images/logo.png',
                height: 100,
                errorBuilder: (context, error, stackTrace) => 
                  const Icon(Icons.medical_services_outlined, size: 80, color: Colors.blueGrey),
              ),
              const SizedBox(height: 20),
              
              const Text(
                "Staff Portal",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              const Text(
                "Secure Access for Clinic Staff",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Email Input
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Staff Email",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                ),
              ),
              const SizedBox(height: 20),

              // Password Input
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                ),
              ),
              const SizedBox(height: 10),

              // Remember Me Checkbox
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    activeColor: Colors.blueGrey[800],
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value!;
                      });
                    },
                  ),
                  const Text("Remember Me"),
                ],
              ),
              const SizedBox(height: 20),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("LOGIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}