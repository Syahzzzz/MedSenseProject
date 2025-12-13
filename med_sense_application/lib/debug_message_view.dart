import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DebugMessageView extends StatefulWidget {
  const DebugMessageView({super.key});

  @override
  State<DebugMessageView> createState() => _DebugMessageViewState();
}

class _DebugMessageViewState extends State<DebugMessageView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allMessages = [];
  String _myAuthId = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _myAuthId = _supabase.auth.currentUser?.id ?? "Not Logged In";
    _fetchAllMessages();
  }

  Future<void> _fetchAllMessages() async {
    try {
      // Fetch LAST 20 messages regardless of recipient
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
            child: Text("My Current ID:\n$_myAuthId", style: const TextStyle(fontFamily: "monospace", fontWeight: FontWeight.bold)),
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
                      final isMatch = recipientId == _myAuthId;

                      return Card(
                        color: isMatch ? Colors.green[50] : Colors.red[50],
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          title: Text(msg['message_content'] ?? "No Content"),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("To: $recipientId"),
                              Text("From: ${msg['sender_id']}"),
                              if (!isMatch) 
                                const Text("MISMATCH: This message was sent to a different ID!", 
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          trailing: isMatch 
                              ? const Icon(Icons.check, color: Colors.green)
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