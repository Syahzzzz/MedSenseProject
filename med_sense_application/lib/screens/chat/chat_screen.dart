import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_sense_application/widgets/message_bubble.dart';
import 'dart:convert'; // Add this import for JSON encoding/decoding

class ChatScreen extends StatefulWidget {
  final String? queueToken;
  final bool isBot;
  final String? receiverId;   // The ID of the person receiving the message
  final String? receiverName;
  final String senderType;    // 'patient' or 'staff'
  final String? customCurrentUserId; // Optional: Override the Auth ID (e.g., use Staff Table ID)

  const ChatScreen({
    super.key, 
    this.queueToken, 
    this.isBot = true,
    this.receiverId,
    this.receiverName,
    this.senderType = 'patient', // Default to patient
    this.customCurrentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState(); 
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final _supabase = Supabase.instance.client;
  
  // Bot variables
  final List<Map<String, dynamic>> _botMessages = [];
  
  // Human Chat Variables
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _chatChannel;
  bool _isLoading = false;
  
  String? _currentUserId;

  String get _effectiveUserId => widget.customCurrentUserId ?? _currentUserId ?? '';

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    _markChatAsRead();
    
    // Setup real-time if not bot
    if (!widget.isBot && _effectiveUserId.isNotEmpty && widget.receiverId != null) {
      _setupChat();
    }
  }

  @override
  void dispose() {
    _chatChannel?.unsubscribe();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markChatAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    
    // 1. Legacy Global (keep for simple checks)
    await prefs.setString('last_viewed_chat_time', now);

    // 2. Per-Conversation Map
    if (widget.receiverId != null) {
      String? jsonStr = prefs.getString('read_timestamps');
      Map<String, dynamic> timestamps = {};
      if (jsonStr != null) {
        try {
          timestamps = jsonDecode(jsonStr);
        } catch (_) {}
      }
      
      timestamps[widget.receiverId!] = now;
      await prefs.setString('read_timestamps', jsonEncode(timestamps));
    }
  }

  void _setupChat() {
    _fetchHistory();
    _subscribeToRealtime();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('Message')
          .select()
          .or('sender_id.eq.$_effectiveUserId,recipient_id.eq.$_effectiveUserId')
          .order('sent_at', ascending: true); // Oldest first for history

      // Filter strict conversation partners in Dart to avoid complex OR logic with AND in Supabase if needed
      // (Though RLS usually handles this, we double check to match specific conversation)
      final filtered = List<Map<String, dynamic>>.from(response).where((m) {
        final sender = m['sender_id'];
        final recipient = m['recipient_id'];
        return (sender == _effectiveUserId && recipient == widget.receiverId) ||
               (sender == widget.receiverId && recipient == _effectiveUserId);
      }).toList();

      if (mounted) {
        setState(() {
          _messages = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching chat history: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToRealtime() {
    _chatChannel = _supabase.channel('public:Message:$_effectiveUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Message',
          callback: (payload) {
             final newMsg = payload.newRecord;
             final sender = newMsg['sender_id'];
             final recipient = newMsg['recipient_id'];
             
             // Check if this message belongs to THIS conversation
             bool isRelevant = (sender == _effectiveUserId && recipient == widget.receiverId) ||
                               (sender == widget.receiverId && recipient == _effectiveUserId);
             
             if (isRelevant && mounted) {
                // Deduplicate: If we just sent it, we might have added it optimistically.
                // We can check if we have a message with same content & close timestamp, or just rely on IDs if available.
                // Since we don't have the ID for optimistic messages easily, we'll just append.
                // Optimistic messages usually don't have 'message_id' from DB yet or we generated one.
                
                // Simple De-duplication check based on ID
                final exists = _messages.any((m) => m['message_id'] == newMsg['message_id']);
                if (!exists) {
                   setState(() {
                      _messages.add(newMsg);
                   });
                }
             }
          },
        )
        .subscribe();
  }

  String _formatTime(dynamic dt) {
    if (dt == null) return "";
    DateTime parsed;
    if (dt is DateTime) {
      parsed = dt;
    } else if (dt is String) {
      parsed = DateTime.tryParse(dt) ?? DateTime.now();
    } else {
      parsed = DateTime.now();
    }
    
    final hour = parsed.hour > 12 ? parsed.hour - 12 : (parsed.hour == 0 ? 12 : parsed.hour);
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  Future<void> _sendMessage() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty) return;
    _controller.clear();

    if (widget.isBot) {
      _sendBotMessage(msg);
    } else {
      _sendHumanMessage(msg);
    }
  }

  // --- BOT LOGIC ---
  Future<void> _sendBotMessage(String msg) async {
    setState(() {
      _botMessages.add({
        "text": msg, 
        "isUser": true,
        "time": _formatTime(DateTime.now())
      });
    });

    try {
      // Fallback for demo/prototype if API isn't running
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _botMessages.add({
            "text": "I received: \"$msg\". (Bot AI connection pending)", 
            "isUser": false,
            "time": _formatTime(DateTime.now())
          });
        });
      }
    } catch (e) {
      debugPrint("Bot error: $e");
    }
  }

  // --- HUMAN (STAFF/PATIENT) LOGIC ---
  Future<void> _sendHumanMessage(String msg) async {
    if (_effectiveUserId.isEmpty || widget.receiverId == null) return;

    // 1. Optimistic Update
    final tempMsg = {
      'message_id': 'temp_${DateTime.now().millisecondsSinceEpoch}', // Temp ID
      'sender_id': _effectiveUserId,
      'recipient_id': widget.receiverId,
      'message_content': msg,
      'sent_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(tempMsg);
    });

    try {
      // 2. Insert into DB
      await _supabase.from('Message').insert({
        'sender_type': widget.senderType, 
        'sender_id': _effectiveUserId,
        'recipient_id': widget.receiverId, 
        'message_content': msg,            
      });
      // We rely on Realtime to bring back the "real" message with correct ID, 
      // or we could fetch the result.
      // Ideally, we'd replace the tempMsg with the real one, but for now, duplicates are unlikely 
      // to be visually jarring if we don't double-add in the subscription callback.
    } on PostgrestException catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['message_id'] == tempMsg['message_id']);
        });
        
        if (e.code == '23503') {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("System Error: Database restricts sending to this user type. Please contact admin."),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${e.message}"), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
           _messages.removeWhere((m) => m['message_id'] == tempMsg['message_id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error sending: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isBot ? 'BotSense 🦷' : (widget.receiverName ?? 'Chat');
    final primaryColor = widget.isBot ? const Color(0xFF2196F3) : const Color(0xFFFBC02D);
    final textColor = widget.isBot ? Colors.white : Colors.black;
    final appBarColor = widget.isBot ? const Color(0xFF2196F3) : Colors.white;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: appBarColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.isBot 
              ? _buildBotList()
              : _buildHumanList(),
          ),
          _buildInputArea(primaryColor),
        ],
      ),
    );
  }

  Widget _buildBotList() {
    if (_botMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("Ask about queue status,\nOKU priority, or dental care!", 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(8),
      itemCount: _botMessages.length,
      itemBuilder: (context, index) {
        final msg = _botMessages[_botMessages.length - 1 - index];
        return MessageBubble(
          text: msg["text"],
          isUser: msg["isUser"],
          time: msg["time"],
        );
      },
    );
  }

  Widget _buildHumanList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text("Start a conversation...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // We reverse the list for display from bottom up
    final displayMessages = _messages.reversed.toList();

    return ListView.builder(
      reverse: true, 
      padding: const EdgeInsets.all(8),
      itemCount: displayMessages.length,
      itemBuilder: (context, index) {
        final msg = displayMessages[index];
        final isMe = msg['sender_id'] == _effectiveUserId;
        return MessageBubble(
          text: msg['message_content'] ?? "", 
          isUser: isMe,
          time: _formatTime(msg['sent_at']),  
        );
      },
    );
  }

  Widget _buildInputArea(Color btnColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            mini: true,
            onPressed: _sendMessage,
            backgroundColor: btnColor,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
