import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'translations.dart';

class StaffSelectionView extends StatefulWidget {
  const StaffSelectionView({super.key});

  @override
  State<StaffSelectionView> createState() => _StaffSelectionViewState();
}

class _StaffSelectionViewState extends State<StaffSelectionView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    try {
      // Fetch staff members from the 'Staff' table.
      // Assumes 'Staff' table has columns: staff_id, name, role, is_available (optional)
      final data = await _supabase
          .from('Staff')
          .select('staff_id, name, role')
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _staffList = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      // Fallback/Mock data if table doesn't exist yet for demo purposes
      if (mounted) {
        setState(() {
          _staffList = [
            {'staff_id': 'staff_1', 'name': 'Dr. Sarah Smith', 'role': 'Dentist'},
            {'staff_id': 'staff_2', 'name': 'Dr. John Doe', 'role': 'Surgeon'},
            {'staff_id': 'staff_3', 'name': 'Nurse Emily', 'role': 'Assistant'},
          ];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          AppTranslations.get('chat_with_staff'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFBC02D)))
          : _staffList.isEmpty
              ? const Center(child: Text("No staff members available."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _staffList.length,
                  itemBuilder: (context, index) {
                    final staff = _staffList[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFFF9C4),
                          child: Text(
                            (staff['name'] as String)[0],
                            style: const TextStyle(color: Color(0xFFFBC02D), fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          staff['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(staff['role'] ?? 'Staff'),
                        trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFFFBC02D)),
                        onTap: () {
                          // Navigate to Chat Screen with specific staff ID
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                isBot: false,
                                receiverId: staff['staff_id'],
                                receiverName: staff['name'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}