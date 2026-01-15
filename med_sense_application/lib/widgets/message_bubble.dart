import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String? time;
  final double fontSize;
  final bool isBotChat;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.time,
    this.fontSize = 14.0,
    this.isBotChat = false,
  });

  @override
  Widget build(BuildContext context) {
    // Standard Styles
    final standardUserColor = Colors.blue;
    final standardUserTextColor = Colors.white;
    final standardOtherColor = Colors.grey[300];
    final standardOtherTextColor = Colors.black;

    // Futuristic / Bot Styles
    // Bot Message: White background with Cyan border (Tech Clinical Look)
    final botMessageDecoration = BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.cyan, width: 1.5),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomRight: Radius.circular(20),
        bottomLeft: Radius.zero,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.cyan.withValues(alpha: 0.2),
          blurRadius: 6,
          spreadRadius: 1,
        ),
      ],
    );

    // User Message (in Bot Chat): Light Grey background with Purple border
    final userBotMessageDecoration = BoxDecoration(
      color: const Color(0xFFF8F9FA), // Off-white
      border: Border.all(color: Colors.purpleAccent, width: 1.5),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.zero,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.purpleAccent.withValues(alpha: 0.2),
          blurRadius: 6,
          spreadRadius: 1,
        ),
      ],
    );

    BoxDecoration decoration;
    Color textColor;

    if (isBotChat) {
      if (isUser) {
        decoration = userBotMessageDecoration;
        textColor = Colors.black87;
      } else {
        decoration = botMessageDecoration;
        textColor = Colors.black87;
      }
    } else {
      // Standard Chat
      decoration = BoxDecoration(
        color: isUser ? standardUserColor : standardOtherColor,
        borderRadius: BorderRadius.circular(20),
      );
      textColor = isUser ? standardUserTextColor : standardOtherTextColor;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: decoration,
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                fontFamily: isBotChat ? 'Courier' : null, // Monospace for bot feel
                fontWeight: isBotChat ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (time != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
              child: Text(
                time!,
                style: TextStyle(
                  fontSize: 10,
                  color: isBotChat ? Colors.grey[400] : Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
