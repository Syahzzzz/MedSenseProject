import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_sense_application/widgets/message_bubble.dart';
import 'package:med_sense_application/services/tts_manager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// For Android emulator talking to FastAPI on host machine
const String backendBaseUrl = 'http://10.0.2.2:8000';

class ChatScreen extends StatefulWidget {
  final String? queueToken;
  final bool isBot;
  final String? receiverId; // The ID of the person receiving the message
  final String? receiverName;
  final String senderType; // 'patient' or 'staff'
  final String? customCurrentUserId; // Optional: Override the Auth ID
  final bool isOkuMode;

  const ChatScreen({
    super.key,
    this.queueToken,
    this.isBot = true,
    this.receiverId,
    this.receiverName,
    this.senderType = 'patient',
    this.customCurrentUserId,
    this.isOkuMode = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final _supabase = Supabase.instance.client;
  final TtsManager _tts = TtsManager();

  // Bot variables
  final List<Map<String, dynamic>> _botMessages = [];

  // Human Chat Variables
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _chatChannel;
  bool _isLoading = false;

  String? _currentUserId;

  // Reschedule flow state
  int? _pendingRescheduleIndex; // which appointment user picked (0–2)
  List<dynamic> _lastAppointments = [];

  String get _effectiveUserId => widget.customCurrentUserId ?? _currentUserId ?? '';

  @override
  void initState() {
    super.initState();
    _tts.init();
    if (widget.isOkuMode) {
      _tts.setEnabled(true);
      final title =
          widget.isBot ? 'Chat with Bot' : 'Chat with ${widget.receiverName ?? "Staff"}';
      _tts.speak("$title. Type a message at the bottom.");
    }

    _currentUserId = _supabase.auth.currentUser?.id;
    _markChatAsRead();

    // BOT: show welcome menu when opening bot chat
    if (widget.isBot) {
      _addBotWelcomeMenu();
    }

    // Setup real-time if not bot
    if (!widget.isBot && _effectiveUserId.isNotEmpty && widget.receiverId != null) {
      _setupChat();
    }
  }

  void _speak(String text) {
    if (widget.isOkuMode) {
      _tts.speak(text);
    }
  }

  /// BOT: initial menu message
  void _addBotWelcomeMenu() {
    setState(() {
      _botMessages.addAll([
        {
          "text": "Hi, this is BotSense speaking. How can I help you today? 🙂",
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        },
        {
          "text":
              "You can ask me about:\n• your *appointments*\n• your *queue status*\n• or *support* if you want to contact the clinic.\n\nTry typing: appointments, queue, or support.",
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        },
      ]);
    });

    _speak(
      "Greetings! This is your kawaii medical assistant speaking. You can ask about appointments, queue status, or support.",
    );
  }

  @override
  void dispose() {
    _chatChannel?.unsubscribe();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markChatAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc().toIso8601String();

    await prefs.setString('last_viewed_chat_time', now);

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
          .order('sent_at', ascending: true);

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
    _chatChannel = _supabase
        .channel('public:Message:$_effectiveUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Message',
          callback: (payload) {
            final newMsg = payload.newRecord;
            final sender = newMsg['sender_id'];
            final recipient = newMsg['recipient_id'];

            bool isRelevant =
                (sender == _effectiveUserId && recipient == widget.receiverId) ||
                    (sender == widget.receiverId && recipient == _effectiveUserId);

            if (isRelevant && mounted) {
              final exists =
                  _messages.any((m) => m['message_id'] == newMsg['message_id']);
              if (!exists) {
                setState(() {
                  _messages.add(newMsg);
                });

                if (widget.isOkuMode && sender != _effectiveUserId) {
                  _speak(
                    "New message from ${widget.receiverName ?? "Staff"}: ${newMsg['message_content']}",
                  );
                }
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

    final hour =
        parsed.hour > 12 ? parsed.hour - 12 : (parsed.hour == 0 ? 12 : parsed.hour);
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  // Malaysian-style appointment date: 08 Jan 2026, 11:00 AM
  String _formatAppointmentDate(String raw) {
    try {
      DateTime dt = DateTime.parse(raw).toLocal();

      final day = dt.day.toString().padLeft(2, '0');
      const monthNames = [
        "Jan",
        "Feb",
        "Mac",
        "Apr",
        "Mei",
        "Jun",
        "Jul",
        "Ogos",
        "Sep",
        "Okt",
        "Nov",
        "Dis"
      ];
      final monthName = monthNames[dt.month - 1];
      final year = dt.year.toString();

      final hour12 =
          dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';

      return "$day $monthName $year, $hour12:$minute $period";
    } catch (_) {
      return raw;
    }
  }

  Future<String?> _getPatientId() async {
    return Supabase.instance.client.auth.currentUser?.id;
  }

  Future<DateTime?> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );

    if (date == null) return null;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );

    if (time == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  bool _isWithinWorkingHours(DateTime dt) {
    // 9:00 – 21:30 daily (Malaysia clinic hours)
    final startMinutes = 9 * 60;
    final endMinutes = 21 * 60 + 30;
    final m = dt.hour * 60 + dt.minute;
    return m >= startMinutes && m <= endMinutes;
  }

  Future<void> _handleAppointmentsIntent() async {
    final patientId = await _getPatientId();
    if (patientId == null) {
      setState(() {
        _botMessages.add({
          "text":
              "I couldn’t find your account details. Please make sure you’re logged in first, ya.",
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        });
      });
      return;
    }

    try {
      final uri = Uri.parse('$backendBaseUrl/appointments')
          .replace(queryParameters: {'patient_id': patientId});

      final resp = await http.get(uri);

      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);

        _lastAppointments = data;
        _pendingRescheduleIndex = null;

        if (data.isEmpty) {
          setState(() {
            _botMessages.add({
              "text":
                  "At the moment, I don’t see any upcoming appointments under your name.",
              "isUser": false,
              "time": _formatTime(DateTime.now()),
            });
          });
          return;
        }

        final buffer = StringBuffer();
        buffer.writeln("Here are your upcoming appointments:\n");

        for (var item in data.take(3)) {
          final status = (item['status']?.toString() ?? 'Unknown');
          if (status.toLowerCase() == 'cancelled' ||
              status.toLowerCase() == 'completed' ||
              status.toLowerCase() == 'expired') {
            continue;
          }

          final rawDt = item['appointment_datetime']?.toString() ?? '';
          final dt = _formatAppointmentDate(rawDt);

          buffer.writeln("• Date & time: $dt");
          buffer.writeln("  Status      : $status");
          buffer.writeln("");
        }

        if (data.length > 3) {
          buffer.writeln(
            "You have more appointments scheduled. "
            "For full details, please open the Appointments page in the app.",
          );
        }

        setState(() {
          _botMessages.add({
            "text": buffer.toString(),
            "isUser": false,
            "time": _formatTime(DateTime.now()),
          });
        });
      } else {
        setState(() {
          _botMessages.add({
            "text":
                "Sayang, I couldn’t load your appointments from the clinic system. Please try again in a bit.",
            "isUser": false,
            "time": _formatTime(DateTime.now()),
          });
        });
      }
    } catch (e) {
      debugPrint("appointments error: $e");
      setState(() {
        _botMessages.add({
          "text": "Oops! The server went for a coffee break.",
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        });
      });
    }
  }

  Future<void> _handleQueueIntent() async {
    final patientId = await _getPatientId();
    if (patientId == null) {
      setState(() {
        _botMessages.add({
          "text":
              "I couldn’t find your account details. Please make sure you’re logged in first, ya.",
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        });
      });
      return;
    }

    try {
      final uri = Uri.parse('$backendBaseUrl/queue_status')
          .replace(queryParameters: {'patient_id': patientId});

      final resp = await http.get(uri);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);

        if (data['status'] == 'no_active_queue') {
          setState(() {
            _botMessages.add({
              "text":
                  "Right now, I don’t see any active queue under your name. Please check in at the clinic counter to get a queue number.",
              "isUser": false,
              "time": _formatTime(DateTime.now()),
            });
          });
          return;
        }

        final qNum = data['queue_number']?.toString() ?? '-';
        final peopleAhead = data['people_ahead'] ?? 0;
        final qStatus = data['queue_status']?.toString() ?? 'Unknown';
        final estWait = data['estimated_wait_minutes'];

        final buffer = StringBuffer();
        buffer.writeln("Here is your current queue status:");
        buffer.writeln("• Queue number : $qNum");
        buffer.writeln("• People ahead : $peopleAhead");
        buffer.writeln("• Status       : $qStatus");
        if (estWait != null) {
          buffer.writeln("• Est. wait    : ~$estWait minute(s)");
        }

        setState(() {
          _botMessages.add({
            "text": buffer.toString(),
            "isUser": false,
            "time": _formatTime(DateTime.now()),
          });
        });

        if (widget.isOkuMode) {
          _speak(
              "Your queue number is $qNum. There are $peopleAhead people ahead of you. Status: $qStatus.");
        }
      } else {
        setState(() {
          _botMessages.add({
            "text":
                "I couldn’t load your queue details from the clinic system. Please try again in a bit.",
            "isUser": false,
            "time": _formatTime(DateTime.now()),
          });
        });
      }
    } catch (e) {
      debugPrint("queue error: $e");
      setState(() {
        _botMessages.add({
          "text":
              "Oops! I had trouble checking your queue. Maybe the server went for a kopi break.",
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        });
      });
    }
  }

  Future<void> _handleSupportIntent(String userMessage) async {
    final patientId = await _getPatientId();
    if (patientId == null) {
      setState(() {
        _botMessages.add({
          "text":
              "I couldn’t find your account details. Please log in first before sending a request to the clinic.",
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        });
      });
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse('$backendBaseUrl/support'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patient_id': patientId,
          'message': userMessage,
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final msg = data['message']?.toString() ??
            "Your message has been sent to the clinic. Our staff will review it shortly.";

        setState(() {
          _botMessages.add({
            "text": msg,
            "isUser": false,
            "time": _formatTime(DateTime.now()),
          });
        });
      } else {
        setState(() {
          _botMessages.add({
            "text":
                "I tried to send your request but the clinic system returned an error. Please try again later, ya.",
            "isUser": false,
            "time": _formatTime(DateTime.now()),
          });
        });
      }
    } catch (e) {
      debugPrint("support error: $e");
      setState(() {
        _botMessages.add({
          "text":
              "Sayang, there was a network problem while sending your request to the clinic.",
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        });
      });
    }
  }

  Future<void> _handleBookingIntent() async {
    final patientId = await _getPatientId();
    if (patientId == null) {
      setState(() {
        _botMessages.add({
          "text":
              "I couldn’t find your account details. Please log in first before booking, ya.",
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        });
      });
      return;
    }

    setState(() {
      _botMessages.add({
        "text":
            "Sure, let’s book an appointment. Please choose your preferred date and time.",
        "isUser": false,
        "time": _formatTime(DateTime.now()),
      });
    });

    final picked = await _pickDateTime(context);
    if (picked == null) {
      setState(() {
        _botMessages.add({
          "text": "No date selected. Booking cancelled.",
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        });
      });
      return;
    }

    DateTime finalPicked = picked;

    if (!_isWithinWorkingHours(finalPicked)) {
      setState(() {
        _botMessages.add({
          "text":
              "That time is outside clinic hours. Please pick a time between 9:00 AM and 9:30 PM.",
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        });
      });

      // Immediately let user pick again
      final retry = await _pickDateTime(context);
      if (retry == null) {
        return;
      }
      if (!_isWithinWorkingHours(retry)) {
        setState(() {
          _botMessages.add({
            "text":
                "Still outside clinic hours. Please type 'book' again and choose a time within 9:00 AM–9:30 PM.",
            "isUser": false,
            "time": _formatTime(DateTime.now()),
          });
        });
        return;
      }

      finalPicked = retry;
    }

    try {
      final resp = await http.post(
        Uri.parse('$backendBaseUrl/appointments/book'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patient_id': patientId,
          'preferred_datetime': finalPicked.toUtc().toIso8601String(),
          // Later: add 'doctor_id' / 'service_id' when you have that context
        }),
      );

      if (resp.statusCode == 200) {
        setState(() {
          _botMessages.add({
            "text":
                "Okay, I’ve submitted your booking request for ${_formatAppointmentDate(finalPicked.toIso8601String())}. The clinic will confirm it soon.",
            "isUser": false,
            "time": _formatTime(DateTime.now()),
          });
        });
      } else {
        final data = jsonDecode(resp.body);
        final detail = data['detail']?.toString() ??
            "I couldn’t create the booking just now. Please try again later or use the main booking page.";
        setState(() {
          _botMessages.add({
            "text": detail,
            "isUser": false,
            "time": _formatTime(DateTime.now()),
          });
        });
      }
    } catch (e) {
      debugPrint("booking error: $e");
      setState(() {
        _botMessages.add({
          "text":
              "There was a problem talking to the booking system. Please try again shortly.",
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        });
      });
    }
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

  // --- BOT LOGIC with nurse-like responses + backend calls ---
  Future<void> _sendBotMessage(String msg) async {
    // Add user message to bot list
    setState(() {
      _botMessages.add({
        "text": msg,
        "isUser": true,
        "time": _formatTime(DateTime.now()),
      });
    });

    final lower = msg.toLowerCase().trim();

    // Waiting for user to pick which appointment (1–3)
    if (_pendingRescheduleIndex == -1 &&
        RegExp(r'^[1-3]$').hasMatch(lower)) {
      final idx = int.parse(lower) - 1;
      if (idx >= 0 && idx < _lastAppointments.length) {
        _pendingRescheduleIndex = idx;

        setState(() {
          _botMessages.add({
            "text": "Okay, choose your new date and time from the picker.",
            "isUser": false,
            "time": _formatTime(DateTime.now()),
          });
        });

        final ctx = context;
        Future.microtask(() async {
          final picked = await _pickDateTime(ctx);
          if (picked == null) {
            setState(() {
              _botMessages.add({
                "text":
                    "No new date selected. We’ll keep your current appointment.",
                "isUser": false,
                "time": _formatTime(DateTime.now()),
              });
            });
            _pendingRescheduleIndex = null;
            return;
          }

          if (!_isWithinWorkingHours(picked)) {
            setState(() {
              _botMessages.add({
                "text":
                    "That time is outside clinic hours. Please pick a time between 9:00 AM and 9:30 PM.",
                "isUser": false,
                "time": _formatTime(DateTime.now()),
              });
            });
            _pendingRescheduleIndex = null;
            return;
          }

          final appt = _lastAppointments[_pendingRescheduleIndex!];
          final apptId = appt['appointment_id'].toString();

          final patientId = await _getPatientId();
          if (patientId == null) {
            setState(() {
              _botMessages.add({
                "text": "I couldn't verify your account. Please log in again.",
                "isUser": false,
                "time": _formatTime(DateTime.now()),
              });
            });
            _pendingRescheduleIndex = null;
            return;
          }

          final resp = await http.post(
            Uri.parse('$backendBaseUrl/appointments/reschedule'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'appointment_id': apptId,
              'new_datetime': picked.toUtc().toIso8601String(),
            }),
          );

          if (resp.statusCode == 200) {
            setState(() {
              _botMessages.add({
                "text":
                    "All set. Your appointment has been rescheduled to ${_formatAppointmentDate(picked.toIso8601String())}.",
                "isUser": false,
                "time": _formatTime(DateTime.now()),
              });
            });
          } else {
            final data = jsonDecode(resp.body);
            final detail = data['detail']?.toString() ??
                "I couldn't complete the reschedule. Please try again or contact the clinic.";
            setState(() {
              _botMessages.add({
                "text": detail,
                "isUser": false,
                "time": _formatTime(DateTime.now()),
              });
            });
          }

          _pendingRescheduleIndex = null;
        });
      }
      return;
    }

    // Appointments → call backend
    if (lower.contains('appointment')) {
      await _handleAppointmentsIntent();
      if (widget.isOkuMode) {
        _speak("I am showing your appointments from the clinic system.");
      }
      return;
    }

    // Queue → call backend
    if (lower.contains('queue')) {
      await _handleQueueIntent();
      return;
    }

    // Reschedule / change appointment → guided flow
    if (lower.contains('reschedule') ||
        lower.contains('change my appointment') ||
        lower.contains('change appointment')) {
      if (_lastAppointments.isEmpty) {
        await _handleAppointmentsIntent();
      }

      if (_lastAppointments.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln("Which appointment would you like to reschedule?");
        for (var i = 0; i < _lastAppointments.length && i < 3; i++) {
          final item = _lastAppointments[i];
          final rawDt = item['appointment_datetime']?.toString() ?? '';
          final dt = _formatAppointmentDate(rawDt);
          final status = (item['status']?.toString() ?? 'Unknown');
          buffer.writeln("${i + 1}. $dt  • $status");
        }
        buffer.writeln("\nReply with 1, 2, or 3.");

        _pendingRescheduleIndex = -1;

        setState(() {
          _botMessages.add({
            "text": buffer.toString(),
            "isUser": false,
            "time": _formatTime(DateTime.now()),
          });
        });
      }
      return;
    }

    // Booking
    if (lower.contains('book') || lower.contains('booking')) {
      await _handleBookingIntent();
      return;
    }

    // Support / contact clinic / refund
    if (lower.contains('support') ||
        lower.contains('help') ||
        lower.contains('contact') ||
        lower.contains('refund')) {
      await _handleSupportIntent(msg);
      if (widget.isOkuMode) {
        _speak("I have sent your request to the clinic staff.");
      }
      return;
    }

    // Default fallback
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      final reply =
          "Sayang, I’ve received your message: \"$msg\".\n\nFor now, I understand best when you ask about *appointments*, *queue*, *booking*, or *support*. You can also say things like:\n• \"Check my appointment\"\n• \"Check my queue\"\n• \"I want to change my appointment\"\n• \"Book appointment\"";
      setState(() {
        _botMessages.add({
          "text": reply,
          "isUser": false,
          "time": _formatTime(DateTime.now()),
        });
      });
      if (widget.isOkuMode) {
        _speak(
            "I have received your message. Try asking about appointments, queue, booking, or support.");
      }
    }
  }

  // --- HUMAN (STAFF/PATIENT) LOGIC ---
  Future<void> _sendHumanMessage(String msg) async {
    if (_effectiveUserId.isEmpty || widget.receiverId == null) return;

    final tempMsg = {
      'message_id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': _effectiveUserId,
      'recipient_id': widget.receiverId,
      'message_content': msg,
      'sent_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(tempMsg);
    });

    try {
      await _supabase.from('Message').insert({
        'sender_type': widget.senderType,
        'sender_id': _effectiveUserId,
        'recipient_id': widget.receiverId,
        'message_content': msg,
      });
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['message_id'] == tempMsg['message_id']);
        });

        if (e.code == '23503') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "System Error: Database restricts sending to this user type. Please contact admin."),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: ${e.message}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['message_id'] == tempMsg['message_id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sending: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isBot ? 'BotSense 🦷' : (widget.receiverName ?? 'Chat');
    final primaryColor =
        widget.isBot ? const Color(0xFF2196F3) : const Color(0xFFFBC02D);
    final textColor = widget.isBot ? Colors.white : Colors.black;
    final appBarColor = widget.isBot ? const Color(0xFF2196F3) : Colors.white;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: appBarColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.isBot ? _buildBotList() : _buildHumanList(),
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
            Text(
              "Ask me about queue status,\nOKU priority, or dental care tips.",
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
        return GestureDetector(
          onTap: () => _speak(msg["text"]),
          child: MessageBubble(
            text: msg["text"],
            isUser: msg["isUser"],
            time: msg["time"],
            fontSize: widget.isOkuMode ? 20.0 : 14.0,
          ),
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

    final displayMessages = _messages.reversed.toList();

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(8),
      itemCount: displayMessages.length,
      itemBuilder: (context, index) {
        final msg = displayMessages[index];
        final isMe = msg['sender_id'] == _effectiveUserId;
        final content = msg['message_content'] ?? "";

        return GestureDetector(
          onTap: () => _speak(content),
          child: MessageBubble(
            text: content,
            isUser: isMe,
            time: _formatTime(msg['sent_at']),
            fontSize: widget.isOkuMode ? 20.0 : 14.0,
          ),
        );
      },
    );
  }

  Widget _buildInputArea(Color btnColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
