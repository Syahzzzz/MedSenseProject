import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugMessageView extends StatefulWidget {
  const DebugMessageView({super.key});

  @override
  State<DebugMessageView> createState() => _DebugMessageViewState();
}

class _DebugMessageViewState extends State<DebugMessageView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allMessages = [];
  String _myAuthId = "";
  String? _myStaffId; // Store resolved Staff ID
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _myAuthId = _supabase.auth.currentUser?.id ?? "Not Logged In";
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // 1. Try to resolve Staff ID from SharedPrefs first (faster)
      final prefs = await SharedPreferences.getInstance();
      _myStaffId = prefs.getString('current_staff_id');

      // 2. Fallback: Try to resolve Staff ID if email exists and prefs failed
      if (_myStaffId == null) {
        final email = _supabase.auth.currentUser?.email;
        if (email != null) {
          final staffData = await _supabase
              .from('Staff')
              .select('staff_id')
              .eq('email', email)
              .maybeSingle();
          
          if (staffData != null) {
            _myStaffId = staffData['staff_id'];
            // Save it for next time
            await prefs.setString('current_staff_id', _myStaffId!);
          }
        }
      }

      // 3. Fetch LAST 20 messages regardless of recipient
      final response = await _supabase
          .from('Message')
          .select()
          .order('sent_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _allMessages = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Debug fetch error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DEBUG: All Messages")),
      body: Column(
        children: [
          Container(
            color: Colors.yellow[100],
            padding: const EdgeInsets.all(8.0),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_myStaffId != null)
                  Text("Staff ID: $_myStaffId", style: const TextStyle(fontFamily: "monospace", fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allMessages.isEmpty 
                  ? const Center(child: Text("Database is actually empty"))
                  : ListView.builder(
                    itemCount: _allMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _allMessages[index];
                      final recipientId = msg['recipient_id'];
                      final senderId = msg['sender_id'];
                      
                      // Check if I am the Recipient
                      final isReceived = (recipientId == _myAuthId) || (recipientId == _myStaffId);
                      // Check if I am the Sender
                      final isSent = (senderId == _myAuthId) || (senderId == _myStaffId);
                      
                      final isMatch = isReceived || isSent;

                      return Card(
                        color: isMatch ? (isSent ? Colors.blue[50] : Colors.green[50]) : Colors.red[50],
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          title: Text(msg['message_content'] ?? "No Content"),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("To: $recipientId"),
                              Text("From: $senderId"),
                              if (!isMatch) 
                                const Text("MISMATCH: Not to/from me!", 
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              if (isReceived)
                                const Text("MATCH: Received Message", 
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                              if (isSent)
                                const Text("MATCH: Sent by Me", 
                                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                          trailing: isMatch 
                              ? (isSent ? const Icon(Icons.arrow_upward, color: Colors.blue) : const Icon(Icons.arrow_downward, color: Colors.green))
                              : const Icon(Icons.close, color: Colors.red),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}