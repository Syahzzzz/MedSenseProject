import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'message_bubble.dart';  // ← Import!

class ChatScreen extends StatefulWidget {
  final String? queueToken;

  const ChatScreen({Key? key, this.queueToken}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState(); }

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> messages = [];
  final String userId = "patient${DateTime.now().millisecondsSinceEpoch}";
  final String fastApiUrl = "https://medsense.com/api/botsense";

Future<void> _sendMessage() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add({
        "text": msg, 
        "isUser": true,
        "time": _formatTime(DateTime.now())
      });
    });
    _controller.clear();

    // Call FastAPI
    try {
      final response = await http.post(
        Uri.parse(fastApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": userId,
          "message": msg,
          "queue_token": widget.queueToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add({
            "text": data["response"], 
            "isUser": false,
            "time": _formatTime(DateTime.now())
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "text": "Server error. Check connection.", 
          "isUser": false,
          "time": _formatTime(DateTime.now())
        });
      });
    }
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text('BotSense 🦷
', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF2196F3),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text("Ask about queue status,\nOKU priority, or dental care!", 
                             textAlign: TextAlign.center,
                             style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[_messages.length - 1 - index];
                      return MessageBubble(
                        text: msg["text"],
                        isUser: msg["isUser"],
                        time: msg["time"],
                      );
                    },
                  ),
          ),
Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Ask queue status, OKU priority, appointments...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: () => _sendMessage(),
                  ),
                ),
                SizedBox(width: 12),
                FloatingActionButton(
                  mini: true,
                  onPressed: _sendMessage,
                  backgroundColor: Color(0xFF2196F3),
                  child: Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}