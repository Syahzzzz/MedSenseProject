import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String? queueToken;
  final bool isBot;
  final String? receiverId;   // The ID of the person receiving the message
  final String? receiverName;
  final String senderType;    // 'patient' or 'staff'

  const ChatScreen({
    super.key, 
    this.queueToken, 
    this.isBot = true,
    this.receiverId,
    this.receiverName,
    this.senderType = 'patient', // Default to patient
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState(); 
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final _supabase = Supabase.instance.client;
  
  // Bot variables
  final List<Map<String, dynamic>> _botMessages = [];
  final String fastApiUrl = "http://10.0.2.2:8000/api/botsense";
  
  // Human Chat Stream
  Stream<List<Map<String, dynamic>>>? _messageStream;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    
    // Setup real-time if not bot
    if (!widget.isBot && _currentUserId != null && widget.receiverId != null) {
      _setupRealtimeChat();
    }
  }

  void _setupRealtimeChat() {
    // SYNC: Using table "Message" and columns from your schema
    _messageStream = _supabase
        .from('Message') 
        .stream(primaryKey: ['message_id']) // Primary key from schema
        .order('sent_at', ascending: true)  // Changed from created_at to sent_at
        .map((maps) {
          // Filter messages relevant to this specific conversation
          return maps.where((m) {
            final sender = m['sender_id'];
            final recipient = m['recipient_id']; // Changed from receiver_id to recipient_id
            
            // Check if message is (Me -> Them) OR (Them -> Me)
            return (sender == _currentUserId && recipient == widget.receiverId) ||
                   (sender == widget.receiverId && recipient == _currentUserId);
          }).toList();
        });
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
    if (_currentUserId == null || widget.receiverId == null) return;

    try {
      // SYNC: Inserting into 'Message' table with new schema columns
      await _supabase.from('Message').insert({
        'sender_type': widget.senderType, // 'patient' or 'staff'
        'sender_id': _currentUserId,
        'recipient_id': widget.receiverId, // Updated column name
        'message_content': msg,            // Updated column name
        // 'sent_at': automatic default
        // 'message_id': automatic default
      });
    } catch (e) {
      if (mounted) {
        // This will catch the Foreign Key violation if you haven't fixed the DB constraint
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
    if (_messageStream == null) {
      return const Center(child: Text("Not connected to chat service"));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _messageStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading messages: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!;
        
        if (messages.isEmpty) {
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

        // We reverse the list because standard chat UIs build from bottom up
        final displayMessages = messages.reversed.toList();

        return ListView.builder(
          reverse: true, // FIX: Only one 'reverse' parameter now
          padding: const EdgeInsets.all(8),
          itemCount: displayMessages.length,
          itemBuilder: (context, index) {
            final msg = displayMessages[index];
            final isMe = msg['sender_id'] == _currentUserId;
            return MessageBubble(
              text: msg['message_content'] ?? "", // SYNC: Updated column
              isUser: isMe,
              time: _formatTime(msg['sent_at']),  // SYNC: Updated column
            );
          },
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