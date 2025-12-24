import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneNumberInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool readOnly;

  const PhoneNumberInputWidget({
    super.key,
    required this.controller,
    this.label = "Phone Number",
    this.hint = "Enter phone number",
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    // Define colors to match the other fields in EditProfileView
    // Note: Ideally these should be passed in or defined in a central theme, 
    // but for this fix we will match the local variables used in EditProfileView.
    const Color lightYellowInput = Color(0xFFFFF9C4);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            // Use the same light yellow color as the other fields
            color: readOnly ? Colors.grey[200] : lightYellowInput, 
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
              // Remove the default filled/fillColor since we are using a Container decoration
              filled: false, 
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              border: InputBorder.none, // Remove default borders to match the custom container style
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a phone number';
              }
              if (value.length < 8) {
                return 'Phone number is too short';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}