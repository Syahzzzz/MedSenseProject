import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase to get user info
import 'package:med_sense_application/utils/translations.dart';

class AddCardView extends StatefulWidget {
  const AddCardView({super.key});

  @override
  State<AddCardView> createState() => _AddCardViewState();
}

class _AddCardViewState extends State<AddCardView> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;

  // Colors from theme
  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _lightYellowInput = const Color(0xFFFFF9C4);

  @override
  void initState() {
    super.initState();
    _loadSavedCard();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Helper to get the current user's email to use as a key suffix
  String _getUserKeySuffix() {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.email ?? ''; 
  }

  // --- Load saved card details specific to the logged-in user ---
  Future<void> _loadSavedCard() async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = _getUserKeySuffix();

    // If no user is logged in (suffix empty), simply don't load anything
    if (suffix.isEmpty) return;

    if (mounted) {
      setState(() {
        _cardNumberController.text = prefs.getString('card_number_$suffix') ?? '';
        _expiryController.text = prefs.getString('card_expiry_$suffix') ?? '';
        _cvvController.text = prefs.getString('card_cvv_$suffix') ?? '';
        _nameController.text = prefs.getString('card_holder_name_$suffix') ?? '';
      });
    }
  }

  // --- Save card details specific to the logged-in user ---
  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final suffix = _getUserKeySuffix();

      if (suffix.isNotEmpty) {
        // Save to local device storage with user-specific keys
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('card_number_$suffix', _cardNumberController.text);
        await prefs.setString('card_expiry_$suffix', _expiryController.text);
        await prefs.setString('card_cvv_$suffix', _cvvController.text);
        await prefs.setString('card_holder_name_$suffix', _nameController.text);
      }

      // Simulate a brief network/processing delay for better UX
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.get('card_saved_msg')),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.get('invalid_form')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          AppTranslations.get('add_new_card'),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Card Visual Mockup ---
              Container(
                height: 200,
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E), // Matte Black look
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Credit Card",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        Icon(Icons.credit_card, color: Colors.white, size: 30),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dynamic Card Number Preview
                        Text(
                          _cardNumberController.text.isEmpty 
                              ? "**** **** **** ****" 
                              : _cardNumberController.text,
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 22, 
                            letterSpacing: 2,
                            fontFamily: 'Courier', // Monospace for alignment
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("CARD HOLDER", style: TextStyle(color: Colors.grey, fontSize: 10)),
                                const SizedBox(height: 4),
                                Text(
                                  _nameController.text.isEmpty 
                                      ? "YOUR NAME" 
                                      : _nameController.text.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("EXPIRES", style: TextStyle(color: Colors.grey, fontSize: 10)),
                                const SizedBox(height: 4),
                                Text(
                                  _expiryController.text.isEmpty 
                                      ? "MM/YY" 
                                      : _expiryController.text,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- Form Fields ---
              
              // Card Number
              Text(AppTranslations.get('card_number'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _cardNumberController,
                hint: "0000 0000 0000 0000",
                icon: Icons.credit_card_outlined,
                keyboardType: TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CardNumberInputFormatter(), // Custom formatter for spaces
                  LengthLimitingTextInputFormatter(19), // 16 digits + 3 spaces
                ],
                onChanged: (val) => setState(() {}), // Update preview
                validator: (value) {
                  if (value == null || value.length < 19) {
                    return "Invalid card number";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  // Expiry
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppTranslations.get('expiry_date'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _expiryController,
                          hint: "MM/YY",
                          icon: Icons.calendar_today_outlined,
                          keyboardType: TextInputType.number,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            ExpiryDateInputFormatter(), // Custom formatter for slash
                            LengthLimitingTextInputFormatter(5), // MM/YY
                          ],
                          onChanged: (val) => setState(() {}), // Update preview
                          validator: (value) {
                            if (value == null || value.length < 5) return "Invalid";
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  // CVV
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppTranslations.get('cvv'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _cvvController,
                          hint: "123",
                          icon: Icons.lock_outline,
                          keyboardType: TextInputType.number,
                          isObscure: true,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          validator: (value) {
                            if (value == null || value.length < 3) return "Invalid";
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Name
              Text(AppTranslations.get('cardholder_name'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hint: "John Doe",
                icon: Icons.person_outline,
                keyboardType: TextInputType.name,
                onChanged: (val) => setState(() {}), // Trigger rebuild to update card preview
                validator: (value) {
                  if (value == null || value.isEmpty) return "Name required";
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryYellow,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        AppTranslations.get('save_card'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    bool isObscure = false,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _lightYellowInput,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        validator: validator,
        obscureText: isObscure,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          errorStyle: const TextStyle(height: 0, color: Colors.transparent), 
        ),
      ),
    );
  }
}

// --- Custom Formatters ---

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    String inputData = newValue.text;
    StringBuffer buffer = StringBuffer();

    for (var i = 0; i < inputData.length; i++) {
      buffer.write(inputData[i]);
      int index = i + 1;
      if (index % 4 == 0 && inputData.length != index) {
        buffer.write(" "); // Add space after every 4 digits
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.toString().length),
    );
  }
}

class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var newText = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      buffer.write(newText[i]);
      var nonZeroIndex = i + 1;
      // Add slash after 2nd char if it's not already there
      if (nonZeroIndex % 2 == 0 && nonZeroIndex != newText.length) {
        buffer.write('/'); 
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
        text: string,
        selection: TextSelection.collapsed(offset: string.length));
  }
}