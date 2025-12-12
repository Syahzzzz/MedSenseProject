import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';

class StaffMessagesView extends StatefulWidget {
  const StaffMessagesView({super.key});

  @override
  State<StaffMessagesView> createState() => _StaffMessagesViewState();
}

class _StaffMessagesViewState extends State<StaffMessagesView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    final currentStaffId = _supabase.auth.currentUser?.id;
    if (currentStaffId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // SYNC: Fetch messages from "Message" table
      // Querying where current user is recipient
      final response = await _supabase
          .from('Message')
          .select('sender_id, sent_at, message_content')
          .eq('recipient_id', currentStaffId)
          .order('sent_at', ascending: false);

      final Set<String> uniqueSenders = {};
      final List<Map<String, dynamic>> tempConversations = [];

      for (var msg in response) {
        final senderId = msg['sender_id'];
        
        // Group by sender to show conversation list
        if (!uniqueSenders.contains(senderId)) {
          uniqueSenders.add(senderId);
          
          String patientName = "Patient";
          try {
            // Attempt to fetch patient name. 
            // NOTE: If sender_id is not in Patient table, this part might return null, handled below.
            final patientData = await _supabase
                .from('Patient')
                .select('name')
                .eq('patient_id', senderId)
                .maybeSingle();
            if (patientData != null) {
              patientName = patientData['name'] ?? "Unknown";
            }
          } catch (_) {
            // Ignore error if patient fetch fails
          }

          tempConversations.add({
            'patient_id': senderId,
            'name': patientName,
            'last_message': msg['message_content'], // SYNC: message_content
            'time': msg['sent_at']                  // SYNC: sent_at
          });
        }
      }

      if (mounted) {
        setState(() {
          _conversations = tempConversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading messages: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Patient Messages"),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_chat_read_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        "No messages yet",
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final convo = _conversations[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey.shade100,
                        radius: 25,
                        child: Icon(Icons.person, color: Colors.blueGrey.shade800),
                      ),
                      title: Text(convo['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        convo['last_message'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        // Navigate to Chat Screen (sending as Staff)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              isBot: false,
                              receiverId: convo['patient_id'],
                              receiverName: convo['name'],
                              senderType: 'staff', // Identify as staff
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}