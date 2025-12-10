import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'staff_dashboard.dart';

class StaffLoginView extends StatefulWidget {
  // We keep this parameter optional so your app doesn't crash if it passes it,
  // but we won't use it for any logic.
  final String? branchName;

  const StaffLoginView({super.key, this.branchName});

  @override
  State<StaffLoginView> createState() => _StaffLoginViewState();
}

class _StaffLoginViewState extends State<StaffLoginView> {
  bool _isLoading = false;
  
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      // Supabase Login
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const StaffDashboard()),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login failed. Check internet connection."), backgroundColor: Colors.red),
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
                'images/logo.png', // Ensure you have this or change to Icon
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
                "Please log in to continue",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Email Input
              TextField(
                controller: _emailController,
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
              const SizedBox(height: 30),

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