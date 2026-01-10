import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_sense_application/screens/chat/chat_screen.dart';
import 'package:med_sense_application/screens/staff/patient_selection_view.dart';
import 'dart:convert';

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
    
    // 1. Try to get from Shared Preferences first (Primary Source)
    final prefs = await SharedPreferences.getInstance();
    String? targetIdToFetch = prefs.getString('current_staff_id');

    // 2. If Prefs empty, try User Auth ID or Email Lookup
    if ((targetIdToFetch == null || targetIdToFetch.isEmpty) && user != null) {
       targetIdToFetch = user.id; // Default to Auth ID
       
       if (user.email != null) {
          try {
            final staffRecord = await _supabase
                .from('Staff')
                .select('staff_id')
                .eq('email', user.email!)
                .maybeSingle();

            if (staffRecord != null) {
              targetIdToFetch = staffRecord['staff_id'];
              await prefs.setString('current_staff_id', targetIdToFetch!);
            }
          } catch (_) {}
       }
    }

    if (targetIdToFetch == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }
      
    _resolvedStaffId = targetIdToFetch;
      
    try {
      // 3. Get LAST 50 messages regardless of owner
      final response = await _supabase
          .from('Message')
          .select()
          .order('sent_at', ascending: false)
          .limit(50);

      // 4. Load Per-Conversation Read Timestamps
      String? jsonStr = prefs.getString('read_timestamps');
      Map<String, dynamic> readTimestamps = {};
      if (jsonStr != null) {
        try {
          readTimestamps = jsonDecode(jsonStr);
        } catch (_) {}
      }

      final Set<String> uniqueContacts = {};
      final List<Map<String, dynamic>> tempConversations = [];

      // 5. Filter in Memory (Dart)
      for (var msg in response) {
        final senderId = msg['sender_id'];
        final recipientId = msg['recipient_id'];
        
        // Check if this message belongs to me
        final isRelevant = (senderId == targetIdToFetch) || (recipientId == targetIdToFetch);

        if (isRelevant) {
          final otherPartyId = (senderId == targetIdToFetch) ? recipientId : senderId;
          
          if (otherPartyId != null && !uniqueContacts.contains(otherPartyId)) {
            uniqueContacts.add(otherPartyId);
            
            String otherPartyName = "Unknown";
            Map<String, dynamic>? patientData;

            // Try to fetch name & details
            try {
              patientData = await _supabase
                  .from('Patient')
                  .select('name, email, phone_number, dob') 
                  .eq('patient_id', otherPartyId)
                  .maybeSingle();
                  
              if (patientData != null) {
                otherPartyName = patientData['name'] ?? "Unknown Patient";
              }
            } catch (e) {
              debugPrint("Error fetching patient details: $e");
            }

            // Determine Unread Status
            bool isUnread = false;
            // Only unread if *they* sent the last message
            if (senderId == otherPartyId) {
               final lastReadTimeStr = readTimestamps[otherPartyId];
               final msgTimeStr = msg['sent_at'];
               if (lastReadTimeStr == null) {
                  isUnread = true; // Never read
               } else {
                  final lastRead = DateTime.parse(lastReadTimeStr);
                  final msgTime = DateTime.parse(msgTimeStr);
                  if (msgTime.isAfter(lastRead)) {
                    isUnread = true;
                  }
               }
            }

            tempConversations.add({
              'patient_id': otherPartyId,
              'name': otherPartyName,
              'email': patientData != null ? patientData['email'] : "No Email",
              'phone': patientData != null ? patientData['phone_number'] : "No Phone",
              'dob': patientData != null ? patientData['dob'] : "No DOB",
              'last_message': msg['message_content'] ?? "Image/File",
              'time': msg['sent_at'],
              'is_unread': isUnread,
            });
          }
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

  void _showProfileDialog(Map<String, dynamic> convo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(convo['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow(Icons.email, convo['email']),
            const SizedBox(height: 10),
            _buildProfileRow(Icons.phone, convo['phone']),
            const SizedBox(height: 10),
            _buildProfileRow(Icons.cake, "DOB: ${convo['dob']}"),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    );
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_resolvedStaffId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PatientSelectionView(staffId: _resolvedStaffId!),
              ),
            ).then((_) => _fetchConversations());
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Staff ID not resolved. Please try again.')),
            );
          }
        },
        backgroundColor: Colors.blueGrey.shade800,
        child: const Icon(Icons.message, color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchConversations,
                  child: _conversations.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.mark_chat_read_outlined, size: 80, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  const Text("No matching conversations found.", style: TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 10),
                                  const Text("New messages will appear here.", 
                                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                            final bool isUnread = convo['is_unread'] ?? false;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              leading: GestureDetector(
                                onTap: () => _showProfileDialog(convo),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blueGrey.shade100,
                                      child: const Icon(Icons.person, color: Colors.white),
                                    ),
                                    if (isUnread)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              title: Text(
                                convo['name'], 
                                style: TextStyle(
                                  fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
                                  color: isUnread ? Colors.black : Colors.black87
                                )
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    convo['last_message'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                      color: isUnread ? Colors.black87 : Colors.grey[600]
                                    ),
                                  ),
                                  Text(
                                    convo['email'] ?? "",
                                    style: TextStyle(fontSize: 10, color: Colors.blueGrey[300]),
                                  ),
                                ],
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
                                      customCurrentUserId: _resolvedStaffId,
                                    ),
                                  ),
                                ).then((_) => _fetchConversations());
                              },
                            );
                          },
                        ),
                ),
          ),
        ],
      ),
    );
  }
}