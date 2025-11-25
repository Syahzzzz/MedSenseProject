import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'phone_number_input.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  File? _imageFile;
  String? _currentAvatarUrl;

  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _lightYellowInput = const Color(0xFFFFF9C4);

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() => _isLoading = true);
      try {
        // Try to fetch from Patient table first
        final data = await _supabase
            .from('Patient')
            .select()
            .eq('patient_id', user.id)
            .maybeSingle();

        if (data != null) {
          setState(() {
            _nameController.text = data['name'] ?? "";
            _emailController.text = data['email'] ?? "";
            _phoneController.text = data['phone_number'] ?? "";
            _dobController.text = data['dob'] ?? "";
            // Note: Patient table schema provided didn't show avatar_url, 
            // so we still try to fetch it from auth metadata if stored there, 
            // or you can add an avatar_url column to Patient table.
            // For now, we keep using metadata for avatar to avoid breaking existing logic unless you add the column.
            _currentAvatarUrl = user.userMetadata?['avatar_url']; 
          });
        } else {
          // Fallback to metadata if no DB record found (migration/legacy support)
          setState(() {
            _nameController.text = user.userMetadata?['full_name'] ?? "";
            _emailController.text = user.email ?? "";
            _phoneController.text = user.userMetadata?['phone_number'] ?? "";
            _dobController.text = user.userMetadata?['dob'] ?? "";
            _currentAvatarUrl = user.userMetadata?['avatar_url'];
          });
        }
      } catch (e) {
        debugPrint("Error loading profile: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
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
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600, 
        maxHeight: 600,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_imageFile == null) return null;

    try {
      final fileExt = _imageFile!.path.split('.').last;
      final fileName = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await _supabase.storage.from('avatars').upload(
        fileName,
        _imageFile!,
        fileOptions: const FileOptions(upsert: true),
      );

      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
      return imageUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload Failed: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      String? newAvatarUrl = _currentAvatarUrl;

      // 1. Attempt Image Upload
      if (_imageFile != null) {
        final url = await _uploadImage(user.id);
        if (url == null && mounted) {
          setState(() => _isLoading = false);
          return; 
        }
        newAvatarUrl = url;
      }

      final String newEmail = _emailController.text.trim();
      final String name = _nameController.text.trim();
      final String phone = _phoneController.text.trim();
      final String dob = _dobController.text.trim();

      // 2. Update Auth Metadata (Keeps auth session in sync)
      final userAttributes = UserAttributes(
        email: (newEmail.isNotEmpty && newEmail != user.email) ? newEmail : null,
        data: {
          'full_name': name,
          'phone_number': phone,
          'dob': dob,
          'avatar_url': newAvatarUrl,
        },
      );
      await _supabase.auth.updateUser(userAttributes);

      // 3. Update Public Patient Table
      await _supabase.from('Patient').update({
        'name': name,
        'phone_number': phone,
        'dob': dob,
        'email': newEmail, // Warning: Changing email here without verifying might cause issues if you use email for uniqueness
      }).eq('patient_id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auth Error: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Error: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Avatar Section ---
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _primaryYellow, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty)
                                ? NetworkImage(_currentAvatarUrl!) as ImageProvider
                                : null,
                        child: (_imageFile == null && (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty))
                            ? const Icon(Icons.person, size: 50, color: Colors.grey)
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryYellow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            const Text("Full Name", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildTextField(_nameController, "Your Name", Icons.person_outline),

            const SizedBox(height: 20),

            const Text("Email Address", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildTextField(_emailController, "Your Email", Icons.email_outlined, readOnly: false),

            const SizedBox(height: 20),

            // Phone Number Widget
            PhoneNumberInputWidget(
              controller: _phoneController,
              label: "Phone Number",
            ),

            const SizedBox(height: 20),

            // --- Birthday Section ---
            const Text("Date of Birth", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: AbsorbPointer(
                child: _buildTextField(
                  _dobController, 
                  "Select Date of Birth", 
                  Icons.calendar_today_outlined,
                ),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryYellow,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool readOnly = false}) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey[200] : _lightYellowInput,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}