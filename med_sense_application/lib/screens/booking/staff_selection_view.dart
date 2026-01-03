import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_sense_application/screens/chat/chat_screen.dart';
import 'package:med_sense_application/utils/translations.dart';
import 'package:med_sense_application/services/tts_manager.dart';

class StaffSelectionView extends StatefulWidget {
  final bool isOkuMode;
  
  const StaffSelectionView({
    super.key,
    this.isOkuMode = false,
  });

  @override
  State<StaffSelectionView> createState() => _StaffSelectionViewState();
}

class _StaffSelectionViewState extends State<StaffSelectionView> {
  final _supabase = Supabase.instance.client;
  final TtsManager _tts = TtsManager();
  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];

  @override
  void initState() {
    super.initState();
    _tts.init();
    if (widget.isOkuMode) {
      _tts.setEnabled(true);
      _tts.speak("Select a staff member to chat with");
    }
    _fetchStaff();
  }

  void _speak(String text) {
    if (widget.isOkuMode) {
      _tts.speak(text);
    }
  }

  Future<void> _fetchStaff() async {
    try {
      final user = _supabase.auth.currentUser;
      final Set<String> unreadSenders = {};

      // 1. Check for unread messages (Globally based on last view time)
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final lastViewedStr = prefs.getString('last_viewed_chat_time');

        if (lastViewedStr != null) {
          final unreadMsgs = await _supabase
              .from('Message')
              .select('sender_id')
              .eq('recipient_id', user.id)
              .gt('sent_at', lastViewedStr);
          
          for (var msg in unreadMsgs) {
            if (msg['sender_id'] != null) {
              unreadSenders.add(msg['sender_id'].toString());
            }
          }
        } else {
           // If never viewed, technically all messages are unread, 
           // but we might skip this or show all. Let's show all if any exist.
           final allMsgs = await _supabase.from('Message').select('sender_id').eq('recipient_id', user.id);
           for (var msg in allMsgs) {
              unreadSenders.add(msg['sender_id'].toString());
           }
        }
      }

      // 2. Fetch staff members
      final data = await _supabase
          .from('Staff')
          .select('staff_id, name, role')
          .order('name', ascending: true);

      // 3. Merge Data
      final List<Map<String, dynamic>> processedList = [];
      for (var s in data) {
         final staffMap = Map<String, dynamic>.from(s);
         staffMap['has_unread'] = unreadSenders.contains(s['staff_id']);
         processedList.add(staffMap);
      }

      if (mounted) {
        setState(() {
          _staffList = processedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      // Fallback/Mock data if table doesn't exist yet for demo purposes
      if (mounted) {
        setState(() {
          _staffList = [
            {'staff_id': 'staff_1', 'name': 'Dr. Sarah Smith', 'role': 'Dentist', 'has_unread': false},
            {'staff_id': 'staff_2', 'name': 'Dr. John Doe', 'role': 'Surgeon', 'has_unread': false},
            {'staff_id': 'staff_3', 'name': 'Nurse Emily', 'role': 'Assistant', 'has_unread': false},
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
                    final bool hasUnread = staff['has_unread'] ?? false;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFFFF9C4),
                              child: Text(
                                (staff['name'] as String)[0],
                                style: const TextStyle(color: Color(0xFFFBC02D), fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (hasUnread)
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
                        title: Text(
                          staff['name'],
                          style: TextStyle(
                            fontWeight: hasUnread ? FontWeight.w900 : FontWeight.bold,
                            color: hasUnread ? Colors.black : Colors.black87,
                            fontSize: widget.isOkuMode ? 20 : 16,
                          ),
                        ),
                        subtitle: Text(
                          staff['role'] ?? 'Staff',
                          style: TextStyle(
                             fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                             color: hasUnread ? Colors.black87 : Colors.grey[600],
                             fontSize: widget.isOkuMode ? 16 : 14,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chat_bubble_outline, 
                          color: hasUnread ? Colors.red : const Color(0xFFFBC02D),
                          size: widget.isOkuMode ? 32 : 24,
                        ),
                        onTap: () {
                          if (widget.isOkuMode) {
                            _speak("Chatting with ${staff['name']}");
                          }
                          // Navigate to Chat Screen with specific staff ID
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                isBot: false,
                                receiverId: staff['staff_id'],
                                receiverName: staff['name'],
                                isOkuMode: widget.isOkuMode,
                              ),
                            ),
                          ).then((_) => _fetchStaff()); // Refresh state on return
                        },
                      ),
                    );
                  },
                ),
    );
  }
}