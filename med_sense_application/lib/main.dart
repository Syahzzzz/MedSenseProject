import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; 

final db = FirebaseFirestore.instance;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- Start of connection test ---
  try {
    // Use a non-existent document reference to avoid creating data
    final docRef = db.collection("test_connection").doc("test_doc");
    await docRef.get();
    print("✅ Firebase connection successful: Able to reach Firestore.");
  } on Exception catch (e) {
    print("❌ Firebase connection failed: $e");
  }
  // --- End of connection test ---

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedSense', 
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 54, 143, 244)),
        useMaterial3: true,
      ),
      
      home: const MyHomePage(title: 'Welcome'), // Updated title
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
  // add state variables here for email/password controllers

  // --- FUNCTIONS & LOGIC ---
  // add login and create account functions here.

  @override
  Widget build(BuildContext context) {
    // This is the gold/yellow color from your design
    final Color primaryColor = const Color(0xFFE6B953);

    return Scaffold(
      // The background color for the top part of the screen
      backgroundColor: primaryColor,
      body: Stack(
        children: [
          // --- Top Header Content ---
          // We use a SafeArea to avoid the status bar
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                // Padding for the header content
                padding: const EdgeInsets.only(top: 60.0, left: 40, right: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Take only needed space
                  children: [
                    // --- The subtle line above the title ---
                    Container(
                      width: 120, // Width of the line
                      height: 2,
                      color: Colors.white, // Line color
                    ),
                    const SizedBox(height: 15),
                    // --- Header Text ---
                    const Text(
                      'Dental Clinic',
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
          // This container is aligned to the bottom and "slides" up
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              // It takes up 75% of the screen height
              height: MediaQuery.of(context).size.height * 0.75,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                // Rounded corners only at the top
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              // We use SingleChildScrollView to prevent overflow on small phones
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40), // Space from top of card

                      // --- Placeholder Image ---
                      // Using a placeholder URL.
                      // You can replace this with your own Image.asset()
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          // Using a royalty-free image as a placeholder
                          'https://images.unsplash.com/photo-1588776712438-d5e56225d3b3?q=80&w=1974&auto=format&fit=crop',
                          width: 250,
                          height: 250,
                          fit: BoxFit.cover,
                          // Fallback in case the network image fails
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 250,
                              height: 250,
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.person, // A simple person icon
                                size: 150,
                                color: Colors.grey[400],
                              ),
                            );
                          },
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
                        'Your Smile Healthy',
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
                            // TODO: Implement Create Account navigation
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 1,
                            // Adding the border
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
                            // TODO: Implement Login logic
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor, // Use the gold color
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
                      const SizedBox(height: 20), // Extra padding at bottom
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