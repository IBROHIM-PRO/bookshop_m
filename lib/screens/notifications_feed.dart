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

  final List<Map<String, String>> _categories = [
    {'key': 'All', 'label': 'Ҳама'},
    {'key': 'Academic', 'label': 'Маориф'},
    {'key': 'Commercial', 'label': 'Харидҳо'},
    {'key': 'Marketing', 'label': 'Аксияҳо'},
    {'key': 'Security', 'label': 'Амният'},
  ];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    _wsService.onNotification = (title, message, category) {
      if (!mounted) return;
      if (_selectedCategory == 'All' || category == _selectedCategory) {
        setState(() {
          _notifications.insert(
            0,
            NotificationModel(
              id: -DateTime.now().millisecondsSinceEpoch,
              title: title,
              message: message,
              type: user.role,
              category: category,
              isRead: false,
              dateCreated: DateTime.now(),
            ),
          );
        });
      }
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
        final String path = _selectedCategory == 'All' 
            ? '/api/notifications' 
            : '/api/notifications?category=$_selectedCategory';
        final response = await ApiService.get(path);
        if (response.statusCode == 200) {
          final List jsonList = jsonDecode(response.body);
          if (!mounted) return;
          setState(() {
            final List<NotificationModel> mapped =
                jsonList.map((n) => NotificationModel.fromJson(n)).toList();
            
            // Filter out test/gibberish notifications containing 'вчаҷв' or 'уқуқ'
            _notifications = mapped.where((n) {
              final title = n.title.toLowerCase();
              final msg = n.message.toLowerCase();
              return !title.contains('вчаҷв') &&
                     !title.contains('уқуқ') &&
                     !msg.contains('вчаҷв') &&
                     !msg.contains('уқуқ');
            }).toList();
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
              category: old.category,
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

  String _getIconAsset(NotificationModel notification) {
    final title = notification.title.toLowerCase();
    final category = notification.category.toLowerCase();

    if (category == 'academic') {
      if (title.contains('нав')) {
        return 'assets/notifications/test_assigned.png';
      } else if (title.contains('супоридан') || title.contains('ҷавоб')) {
        return 'assets/notifications/test_completed.png';
      } else if (title.contains('натиҷа') || title.contains('қабул')) {
        return 'assets/notifications/test_result.png';
      } else if (title.contains('тафтиш') || title.contains('бозгардон')) {
        return 'assets/notifications/academic_progress.png';
      }
      return 'assets/notifications/test_assigned.png';
    } else if (category == 'commercial') {
      if (title.contains('фармоиш')) {
        return 'assets/notifications/order_created.png';
      } else if (title.contains('дастрасӣ')) {
        return 'assets/notifications/book_access_granted.png';
      } else if (title.contains('пардохт') && title.contains('муваффақ')) {
        return 'assets/notifications/payment_success.png';
      } else if (title.contains('пардохт') && title.contains('хато')) {
        return 'assets/notifications/payment_failed.png';
      }
      return 'assets/notifications/order_created.png';
    } else if (category == 'marketing') {
      if (title.contains('нав') || title.contains('илова')) {
        return 'assets/notifications/new_arrival.png';
      } else if (title.contains('аксия') || title.contains('пешниҳод') || title.contains('тахфиф')) {
        return 'assets/notifications/promotion.png';
      }
      return 'assets/notifications/recommendation.png';
    } else if (category == 'security') {
      if (title.contains('ворид') || title.contains('дастгоҳ') || title.contains('сессия') || title.contains('амният')) {
        return 'assets/notifications/security_alert.png';
      }
      return 'assets/notifications/system_alert.png';
    }
    return 'assets/notifications/system_alert.png';
  }

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

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (_selectedCategory != cat['key']) {
                        setState(() {
                          _selectedCategory = cat['key']!;
                          _isLoading = true;
                        });
                        _fetchNotifications();
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E7431)
                            : (isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F4F1)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1E7431)
                              : (isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFD1E2D5)),
                        ),
                      ),
                      child: Text(
                        cat['label']!,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDarkMode ? Colors.white.withOpacity(0.8) : const Color(0xFF1A1F1C)),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: textColor),
                  )
                : _notifications.isEmpty
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
                                Opacity(
                                  opacity: notification.isRead ? 0.6 : 1.0,
                                  child: Image.asset(
                                    _getIconAsset(notification),
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.contain,
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
