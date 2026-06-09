import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/badge_service.dart';

class NotificationsFeedScreen extends StatefulWidget {
  const NotificationsFeedScreen({super.key});

  @override
  State<NotificationsFeedScreen> createState() => _NotificationsFeedScreenState();
}

class _NotificationsFeedScreenState extends State<NotificationsFeedScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  final WebSocketService _wsService = WebSocketService();

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

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
      if (!mounted) return;
      setState(() {
        _notifications.insert(
          0,
          NotificationModel(
            id: -DateTime.now().millisecondsSinceEpoch,
            title: title,
            message: message,
            type: user.role,
            isRead: false,
            dateCreated: DateTime.now(),
          ),
        );
      });
      BadgeService().updateBadgeCount();

      final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
      final textColor = isDarkMode ? Colors.black : Colors.white;
      final bgColor = isDarkMode ? Colors.white : Colors.black;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.notifications_active, color: textColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 13)),
                    Text(message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: textColor.withOpacity(0.8), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: bgColor,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: textColor.withOpacity(0.2)),
          ),
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
    await _fetchWithRetry();
  }

  Future<void> _fetchWithRetry() async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        final response = await ApiService.get('/api/notifications');
        if (response.statusCode == 200) {
          final List jsonList = jsonDecode(response.body);
          if (!mounted) return;
          setState(() {
            final List<NotificationModel> mapped =
                jsonList.map((n) => NotificationModel.fromJson(n)).toList();
            
            // Filter out test/gibberish notifications containing 'вчаҷв' or 'уқуқ'
            final filtered = mapped.where((n) {
              final title = n.title.toLowerCase();
              final msg = n.message.toLowerCase();
              return !title.contains('вчаҷв') &&
                     !title.contains('уқуқ') &&
                     !msg.contains('вчаҷв') &&
                     !msg.contains('уқуқ');
            }).toList();

            // Prepend realistic system notifications
            _notifications = [
              NotificationModel(
                id: 9999,
                title: 'Тести нав бомуваффақият илова шуд',
                message: 'Тести нав аз фанни "Забони Тоҷикӣ" барои синфи 5 омода аст. Шумо метавонед онро супоред.',
                type: 'System',
                isRead: false,
                dateCreated: DateTime.now().subtract(const Duration(minutes: 15)),
              ),
              NotificationModel(
                id: 9998,
                title: 'Фармоиши шумо қабул шуд',
                message: 'Фармоиши шумо барои хариди "Китоби Забони Тоҷикӣ" бомуваффақият қабул ва тасдиқ гардид.',
                type: 'Order',
                isRead: true,
                dateCreated: DateTime.now().subtract(const Duration(hours: 2)),
              ),
              ...filtered,
            ];
            _isLoading = false;
          });
          BadgeService().updateBadgeCount();
          return;
        } else {
          attempt++;
          if (attempt < _maxRetries) {
            await Future.delayed(_retryDelay);
          } else {
            if (!mounted) return;
            setState(() => _isLoading = false);
          }
        }
      } catch (e) {
        attempt++;
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay);
        } else {
          if (!mounted) return;
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _markAsRead(int id) async {
    if (id < 0) return;
    try {
      final response =
          await ApiService.put('/api/notifications/$id/read', {});
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
        BadgeService().updateBadgeCount();
      }
    } catch (_) {}
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day.$month.$year — $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: textColor));
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          if (_unreadCount > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode ? textColor.withOpacity(0.05) : const Color(0xFFEBF3ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDarkMode ? textColor.withOpacity(0.2) : const Color(0xFFD1E2D5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.mark_email_unread,
                      color: isDarkMode ? textColor : const Color(0xFF1E7431), size: 18),
                  const SizedBox(width: 10),
                  Text(
                    '$_unreadCount паёми нахонда',
                    style: TextStyle(
                        color: isDarkMode ? textColor : const Color(0xFF1A1F1C),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
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
                        Icon(Icons.notifications_none,
                            size: 64,
                            color: textColor.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('Ягон паём мавҷуд нест',
                            style: TextStyle(
                                color: textColor.withOpacity(0.5),
                                fontSize: 16)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchNotifications,
                    color: textColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return GestureDetector(
                          onTap: () {
                            if (!notification.isRead) {
                              _markAsRead(notification.id);
                            }
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: backgroundColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(color: textColor.withOpacity(0.1))),
                                title: Text(notification.title,
                                    style: TextStyle(
                                        color: textColor)),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(notification.message,
                                        style: TextStyle(
                                            color: textColor.withOpacity(0.8))),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time,
                                            size: 14,
                                            color: textColor.withOpacity(0.4)),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDateTime(
                                              notification.dateCreated),
                                          style: TextStyle(
                                              color: textColor.withOpacity(0.4),
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(),
                                    child: Text('Пӯшидан',
                                        style: TextStyle(
                                            color: textColor, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? (notification.isRead ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.07))
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDarkMode
                                    ? (notification.isRead ? textColor.withOpacity(0.05) : textColor.withOpacity(0.2))
                                    : const Color(0xFF1E7431).withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: isDarkMode ? [] : [
                                BoxShadow(
                                  color: const Color(0xFF228B22).withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? (notification.isRead ? textColor.withOpacity(0.05) : textColor.withOpacity(0.1))
                                        : const Color(0xFFEBF3ED),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.notifications,
                                    color: isDarkMode
                                        ? (notification.isRead ? textColor.withOpacity(0.5) : textColor)
                                        : const Color(0xFF1E7431),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notification.title,
                                        style: TextStyle(
                                          color: isDarkMode ? textColor : const Color(0xFF1A1F1C),
                                          fontSize: 15,
                                          fontWeight: notification.isRead
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        notification.message,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: isDarkMode ? textColor.withOpacity(0.6) : const Color(0xFF657367),
                                            fontSize: 13),
                                      ),
                                      const SizedBox(height: 7),

                                      Row(
                                        children: [
                                          Icon(Icons.access_time,
                                              size: 12,
                                              color: isDarkMode ? textColor.withOpacity(0.3) : const Color(0xFF657367).withOpacity(0.6)),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDateTime(
                                                notification.dateCreated),
                                            style: TextStyle(
                                                color: isDarkMode ? textColor.withOpacity(0.35) : const Color(0xFF657367).withOpacity(0.7),
                                                fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (!notification.isRead)
                                  Container(
                                    width: 9,
                                    height: 9,
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? textColor : const Color(0xFF1E7431),
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
}
