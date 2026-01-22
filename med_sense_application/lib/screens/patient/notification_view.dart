import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:med_sense_application/services/notification_service.dart';

class NotificationView extends StatefulWidget {
  const NotificationView({super.key});

  @override
  State<NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<NotificationView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isOkuEnabled = false;
  List<Map<String, dynamic>> _notifications = [];
  RealtimeChannel? _notificationChannel;

  // Theme Colors
  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadOkuSettings();
    _fetchNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      _supabase.removeChannel(_notificationChannel!);
    }
    super.dispose();
  }

  Future<void> _initializeService() async {
    await NotificationService().init();
    await Permission.notification.request();
  }

  Future<void> _loadOkuSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isOkuEnabled = prefs.getBool('is_oku_enabled') ?? false;
      });
    }
  }

  void _subscribeToNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Use a unique channel name for this view to avoid conflict with Dashboard
    _notificationChannel = _supabase
        .channel('public:Notification:${user.id}:view')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Notification',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: user.id,
          ),
          callback: (payload) {
            _handleNewNotification(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _handleNewNotification(Map<String, dynamic> newRecord) {
    // Show Local Notification (Restored to ensure delivery)
    NotificationService().showNotification(
      newRecord['notification_id'].hashCode,
      'New Notification',
      newRecord['message_content'] ?? 'You have a new message',
    );

    // Update UI immediately
    if (mounted) {
      setState(() {
        _notifications.insert(0, newRecord);
      });
    }
  }

  Future<void> _fetchNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('Notification')
          .select()
          .eq('recipient_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _supabase
          .from('Notification')
          .update({'is_read': true})
          .eq('notification_id', id);
      
      // Update local state
      setState(() {
        final index = _notifications.indexWhere((n) => n['notification_id'] == id);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
        }
      });
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _supabase.from('Notification').delete().eq('notification_id', id);
      setState(() {
        _notifications.removeWhere((n) => n['notification_id'] == id);
      });
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays == 0) {
        return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
      } else if (diff.inDays == 1) {
        return "Yesterday";
      } else {
        return "${dt.day}/${dt.month}/${dt.year}";
      }
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Sizing for OKU
    final double padding = _isOkuEnabled ? 24.0 : 16.0;
    final double iconSize = _isOkuEnabled ? 32.0 : 20.0;
    final double messageSize = _isOkuEnabled ? 20.0 : 14.0;
    final double dateSize = _isOkuEnabled ? 16.0 : 12.0;
    final double emptyIconSize = _isOkuEnabled ? 80.0 : 64.0;
    final double emptyTextSize = _isOkuEnabled ? 22.0 : 16.0;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Notifications', 
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: _isOkuEnabled ? 24 : 20
          )
        ),
        backgroundColor: _primaryYellow,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryYellow))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: emptyIconSize, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(fontSize: emptyTextSize, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final bool isRead = notification['is_read'] ?? false;
                    final String message = notification['message_content'] ?? '';
                    final String date = _formatDate(notification['created_at']);

                    return Dismissible(
                      key: Key(notification['notification_id']),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) => _deleteNotification(notification['notification_id']),
                      child: Card(
                        color: isRead ? Colors.white : Colors.yellow[50],
                        elevation: isRead ? 1 : 2,
                        margin: EdgeInsets.only(bottom: _isOkuEnabled ? 16 : 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () {
                            if (!isRead) _markAsRead(notification['notification_id']);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: EdgeInsets.all(padding),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isRead ? Colors.grey[200] : _primaryYellow.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.notifications,
                                    size: iconSize,
                                    color: isRead ? Colors.grey : _primaryYellow,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message,
                                        style: TextStyle(
                                          fontSize: messageSize,
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        date,
                                        style: TextStyle(fontSize: dateSize, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}