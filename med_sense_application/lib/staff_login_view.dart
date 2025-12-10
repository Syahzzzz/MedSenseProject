import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'staff_dashboard.dart';

class StaffLoginView extends StatefulWidget {
  final String branchName; // Receive the branch name

  const StaffLoginView({super.key, required this.branchName});

  @override
  State<StaffLoginView> createState() => _StaffLoginViewState();
}

class _StaffLoginViewState extends State<StaffLoginView> {
  // Toggle State
  bool _isLogin = true; // true = Login, false = New Staff
  bool _isLoading = false;
  
  // Controllers
  final _staffIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Strict ID Mapping per Branch
  final Map<String, List<String>> _branchStaffIds = {
    'Rawang': ['10001', '10002'],       // Rawang IDs start with 10
    'Selayang': ['20001', '20002'],     // Selayang IDs start with 20
    'Kuala Lumpur': ['30001', '30002'], // KL IDs start with 30
  };

  final _supabase = Supabase.instance.client;

  // Theme Colors
  final Color _staffColor = const Color(0xFF37474F); // Dark BlueGrey
  final Color _staffAccent = const Color(0xFFCFD8DC);

  @override
  void dispose() {
    _staffIdController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Helper: Validate ID for Current Branch ---
  bool _isIdValidForBranch(String id) {
    final validIds = _branchStaffIds[widget.branchName] ?? [];
    return validIds.contains(id);
  }

  // --- Logic: Register New Staff ---
  Future<void> _handleRegister() async {
    final staffId = _staffIdController.text.trim(); // The 5-digit ID (e.g. 10001)
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();
    final name = _nameController.text.trim();

    // 1. Basic Validation
    if (staffId.isEmpty || email.isEmpty || password.isEmpty || name.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    if (staffId.length < 5 || staffId.length > 6) {
      _showError("Staff ID must be 5-6 digits long");
      return;
    }

    if (password != confirmPass) {
      _showError("Passwords do not match");
      return;
    }

    // 2. HR Validation (Strict Branch Check)
    if (!_isIdValidForBranch(staffId)) {
      _showError("Invalid ID. This ID does not belong to ${widget.branchName}.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 3. Register with Supabase Auth (Creates user in auth.users)
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'role': 'staff',
          'manual_staff_id': staffId, // Saving the 10001 ID in metadata
          'branch': widget.branchName, 
        },
      );

      if (res.user != null) {
        // --- 4. NEW: Sync with your public.Staff table ---
        // We use res.user!.id (UUID) to map to 'staff_id'
        try {
          // *** FIX: Changed 'staff' back to 'Staff' to match your DB ***
          await _supabase.from('Staff').insert({
            'staff_id': res.user!.id, // Matches auth.uid()
            'name': name,
            'email': email,
            'password_hash': password, 
          });
        } catch (dbError) {
          // Show DB error on screen so we know if it fails again
          _showError("Account created, but database sync failed: $dbError");
          debugPrint("Database sync error: $dbError");
          // Not returning here to allow local login setup even if sync fails
        }

        // 5. Save Staff ID -> Email mapping locally for Login convenience
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('staff_email_$staffId', email);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Staff registered successfully! Please login.")),
          );
          setState(() {
            _isLogin = true; // Switch to login tab
            _passwordController.clear();
            _confirmPasswordController.clear();
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError("Registration failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Logic: Staff Login ---
  Future<void> _handleLogin() async {
    final staffId = _staffIdController.text.trim();
    final password = _passwordController.text.trim();

    if (staffId.isEmpty || password.isEmpty) {
      _showError("Please enter Staff ID and Password");
      return;
    }

    // 1. Strict Branch Check before Login
    if (!_isIdValidForBranch(staffId)) {
       _showError("Access Denied: ID $staffId is not authorized for ${widget.branchName}.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Retrieve Email associated with Staff ID
      final prefs = await SharedPreferences.getInstance();
      String? email = prefs.getString('staff_email_$staffId');

      if (email == null) {
        throw "Staff ID not recognized on this device. Please Register first.";
      }

      // 3. Sign in using the retrieved email
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        // Navigate to Staff Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StaffDashboard()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Staff Portal", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _staffColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Branch Info Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, color: Colors.brown),
                    const SizedBox(width: 8),
                    Text(
                      widget.branchName.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                        fontSize: 16
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Hint for Demo purposes
              Text(
                _getBranchHint(),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),

              const SizedBox(height: 20),
              Icon(Icons.admin_panel_settings, size: 80, color: _staffColor),
              const SizedBox(height: 20),
              
              // Toggle Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleButton("Login", true),
                    _buildToggleButton("New Staff", false),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Form Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  children: [
                    // Login uses 5-digit ID, DB uses UUID (handled in background)
                    _buildTextField(_staffIdController, "Staff ID", Icons.badge, isNumeric: true),
                    const SizedBox(height: 15),

                    if (!_isLogin) ...[
                      _buildTextField(_nameController, "Full Name", Icons.person),
                      const SizedBox(height: 15),
                      _buildTextField(_emailController, "Email", Icons.email),
                      const SizedBox(height: 15),
                    ],

                    _buildTextField(_passwordController, "Password", Icons.lock, isPassword: true),
                    
                    if (!_isLogin) ...[
                      const SizedBox(height: 15),
                      _buildTextField(_confirmPasswordController, "Confirm Password", Icons.lock_outline, isPassword: true),
                    ],

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : (_isLogin ? _handleLogin : _handleRegister),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _staffColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading 
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                          : Text(
                              _isLogin ? "LOGIN" : "REGISTER",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getBranchHint() {
    switch (widget.branchName) {
      case 'Rawang': return "Valid IDs: 10001, 10002";
      case 'Selayang': return "Valid IDs: 20001, 20002";
      case 'Kuala Lumpur': return "Valid IDs: 30001, 30002";
      default: return "";
    }
  }

  Widget _buildToggleButton(String text, bool isLoginBtn) {
    final isSelected = _isLogin == isLoginBtn;
    return GestureDetector(
      onTap: () => setState(() => _isLogin = isLoginBtn),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _staffColor : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false, bool isNumeric = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _staffColor),
        hintText: hint,
        filled: true,
        fillColor: _staffAccent.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}