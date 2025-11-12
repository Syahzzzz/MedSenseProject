// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// We import our app's main file to test it
import 'package:med_sense_application/main.dart'; 

void main() {
  // We define a test case. The 'testWidgets' function provides
  // a 'WidgetTester' to interact with.
  testWidgets('Login page smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // This 'pumpWidget' call builds the UI.
    await tester.pumpWidget(const MyApp());

    // --- Test 1: Verify the "Dental Clinic" text is on the screen ---
    // This line looks for a widget that contains the text 'Dental Clinic'.
    expect(find.text('Dental Clinic'), findsOneWidget);

    // --- Test 2: Verify the "Create Account" button text is there ---
    expect(find.text('Create Account'), findsOneWidget);

    // --- Test 3: Verify the "Login" button text is there ---
    expect(find.text('Login'), findsOneWidget);

    // --- Test 4: Verify the placeholder image is on screen ---
    // We can also find widgets by their type.
    // This checks that there is exactly one 'Image' widget on the screen.
    // (Note: This is a simple test and might break if you add more images)
    expect(find.byType(Image), findsOneWidget);
  });
}