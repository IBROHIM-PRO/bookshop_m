import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class NotificationsFeedScreen extends StatefulWidget {
  const NotificationsFeedScreen({super.key});

  @override
  State<NotificationsFeedScreen> createState() => _NotificationsFeedScreenState();
}

class _NotificationsFeedScreenState extends State<NotificationsFeedScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  final WebSocketService _wsService = WebSocketService();

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    _wsService.onNotification = (title, message) {
      // Add live notification at the top of list
      if (!mounted) return;
      setState(() {
        _notifications.insert(
          0,
          NotificationModel(
            id: -DateTime.now().millisecondsSinceEpoch, // temporary local id
            title: title,
            message: message,
            type: user.role,
            isRead: false,
            dateCreated: DateTime.now(),
          ),
        );
      });

      // Show a SnackBar popup
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                    Text(message, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.deepPurpleAccent,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(12),
        ),
      );
    };

    _wsService.connect(user.id, user.role);
  }

  @override
  void dispose() {
    _wsService.disconnect();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await ApiService.get('/api/notifications');
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(response.body);
        setState(() {
          _notifications = jsonList.map((n) => NotificationModel.fromJson(n)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int id) async {
    if (id < 0) return; // Skip local WebSocket-only notifications
    try {
      final response = await ApiService.put('/api/notifications/$id/read', {});
      if (response.statusCode == 200) {
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == id);
          if (index != -1) {
            final old = _notifications[index];
            _notifications[index] = NotificationModel(
              id: old.id,
              title: old.title,
              message: old.message,
              type: old.type,
              isRead: true,
              dateCreated: old.dateCreated,
            );
          }
        });
      }
    } catch (_) {}
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      body: Column(
        children: [
          if (_unreadCount > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_unread, color: Colors.deepPurpleAccent, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    '$_unreadCount паёми нахонда',
                    style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 64, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('Ягон паём мавҷуд нест',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchNotifications,
                    color: Colors.deepPurpleAccent,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return GestureDetector(
                          onTap: () {
                            if (!notification.isRead) _markAsRead(notification.id);
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E173E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text(notification.title, style: const TextStyle(color: Colors.white)),
                                content: Text(notification.message, style: const TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('Пӯшидан', style: TextStyle(color: Colors.deepPurpleAccent)),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: notification.isRead
                                  ? Colors.white.withOpacity(0.02)
                                  : Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: notification.isRead
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.deepPurpleAccent.withOpacity(0.4),
                                width: notification.isRead ? 1 : 1.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: notification.isRead
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.deepPurpleAccent.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.notifications,
                                    color: notification.isRead ? Colors.white54 : Colors.deepPurpleAccent,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notification.title,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        notification.message,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        _timeAgo(notification.dateCreated),
                                        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!notification.isRead)
                                  Container(
                                    width: 9,
                                    height: 9,
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: const BoxDecoration(
                                      color: Colors.deepPurpleAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays >= 1) return '${diff.inDays} рӯз пеш';
    if (diff.inHours >= 1) return '${diff.inHours} соат пеш';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} дақиқа пеш';
    return 'Ҳозир';
  }
}
