import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_sense_application/screens/chat/chat_screen.dart';

class StaffMessagesView extends StatefulWidget {
  const StaffMessagesView({super.key});

  @override
  State<StaffMessagesView> createState() => _StaffMessagesViewState();
}

class _StaffMessagesViewState extends State<StaffMessagesView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  String? _resolvedStaffId; 

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      String targetIdToFetch = user.id; // Default to Auth ID

      // Attempt to resolve correct ID from Staff table via email
      if (user.email != null) {
        try {
          final staffRecord = await _supabase
              .from('Staff')
              .select('staff_id')
              .eq('email', user.email!)
              .maybeSingle();

          if (staffRecord != null) {
            targetIdToFetch = staffRecord['staff_id'];
            debugPrint("Resolved Staff ID via Email: $targetIdToFetch");
          }
        } catch (e) {
          debugPrint("Could not resolve staff ID from table: $e");
        }
      }
      
      _resolvedStaffId = targetIdToFetch;

      debugPrint("Fetching messages for Recipient ID: $targetIdToFetch");
      
      // CORRECTED QUERY SYNTAX HERE
      final response = await _supabase
          .from('Message')
          .select('sender_id, sent_at, message_content')
          .eq('recipient_id', targetIdToFetch) // Correct usage
          .order('sent_at', ascending: false);

      final Set<String> uniqueSenders = {};
      final List<Map<String, dynamic>> tempConversations = [];

      for (var msg in response) {
        final senderId = msg['sender_id'];
        
        if (!uniqueSenders.contains(senderId)) {
          uniqueSenders.add(senderId);
          
          String patientName = "Unknown Patient";
          try {
            final patientData = await _supabase
                .from('Patient')
                .select('name')
                .eq('patient_id', senderId)
                .maybeSingle();
                
            if (patientData != null) {
              patientName = patientData['name'] ?? "Unknown Patient";
            }
          } catch (_) {}

          tempConversations.add({
            'patient_id': senderId,
            'name': patientName,
            'last_message': msg['message_content'] ?? "Image/File",
            'time': msg['sent_at']
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
      debugPrint("Error fetching messages: $e");
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchConversations();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchConversations,
              child: _conversations.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mark_chat_read_outlined, size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                "No messages yet",
                                style: TextStyle(color: Colors.grey[500], fontSize: 16),
                              ),
                              if (_resolvedStaffId != null)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SelectableText(
                                    "Listening on ID:\n$_resolvedStaffId", 
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
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
                            child: const Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(convo['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            convo['last_message'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  isBot: false,
                                  receiverId: convo['patient_id'],
                                  receiverName: convo['name'],
                                  senderType: 'staff',
                                ),
                              ),
                            ).then((_) => _fetchConversations());
                          },
                        );
                      },
                    ),
            ),
    );
  }
}