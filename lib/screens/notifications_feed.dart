import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/badge_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class NotificationsFeedScreen extends StatefulWidget {
  final bool showAppBar;
  const NotificationsFeedScreen({super.key, this.showAppBar = true});

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

  String _getSvgBackground(NotificationModel notification) {
    final category = notification.category.toLowerCase();
    if (category == 'academic') {
      return 'assets/logo/logobackground/exam-svgrepo-com 1.svg';
    } else if (category == 'commercial') {
      if (notification.title.toLowerCase().contains('пардохт')) {
        return 'assets/logo/logobackground/payment-method-svgrepo-com 1.svg';
      }
      return 'assets/logo/logobackground/Vector.svg';
    } else if (category == 'marketing') {
      return 'assets/logo/logobackground/Vector-1.svg';
    } else if (category == 'security') {
      return 'assets/logo/logobackground/system-settings-backup-svgrepo-com 1.svg';
    }
    return 'assets/logo/logobackground/Vector.svg'; // Default
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) return 'Имрӯз';
    if (msgDate == yesterday) return 'Дирӯз';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  List<dynamic> _getGroupedNotifications() {
    List<dynamic> grouped = [];
    String? currentGroup;
    for (var n in _notifications) {
      final group = _formatDateHeader(n.dateCreated);
      if (group != currentGroup) {
        grouped.add(group);
        currentGroup = group;
      }
      grouped.add(n);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF111827);
    final backgroundColor = isDarkMode ? Colors.black : const Color(0xFFF1F8F4); // Light green theme
    final appBarColor = isDarkMode ? Colors.black : Colors.white;

    final groupedList = _getGroupedNotifications();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: widget.showAppBar ? AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Паёмҳо',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            SvgPicture.asset(
              'assets/logo/logobackground/notification-bell-svgrepo-com 1.svg',
              width: 26,
              height: 26,
              colorFilter: ColorFilter.mode(
                isDarkMode ? Colors.white : Colors.black,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ) : null,
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
                            ? const Color(0xFF22873B)
                            : (isDarkMode ? Colors.transparent : Colors.transparent),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF22873B),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        cat['label']!,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF22873B),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
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
                        SvgPicture.asset(
                          'assets/logo/logobackground/notification-bell-svgrepo-com 1.svg',
                          width: 100,
                          height: 100,
                        ),
                        const SizedBox(height: 24),
                        Text('Ягон паём нест',
                            style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                        const SizedBox(height: 8),
                        Text('Мо ба шумо хабар медиҳем,\nвақте ки чизи нав пайдо мешавад.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: isDarkMode ? Colors.white70 : Colors.black.withOpacity(0.6),
                                fontSize: 14)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchNotifications,
                    color: const Color(0xFF22873B),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: groupedList.length,
                      itemBuilder: (context, index) {
                        final item = groupedList[index];

                        if (item is String) {
                          // Date Header
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode ? Colors.white70 : const Color(0xFF111827),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        final notification = item as NotificationModel;

                        return GestureDetector(
                          onTap: () {
                            if (!notification.isRead) {
                              _markAsRead(notification.id);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? (notification.isRead ? const Color(0xFF1C1C1E) : const Color(0xFF2C2C2E))
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isDarkMode ? [] : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Background SVG icon in bottom right
                                Positioned(
                                  right: 10,
                                  bottom: -15,
                                  child: Opacity(
                                    opacity: isDarkMode ? 0.05 : 0.08,
                                    child: Transform.rotate(
                                      angle: -0.26, // tilt like the mockup
                                      child: SvgPicture.asset(
                                        _getSvgBackground(notification),
                                        width: 100,
                                        height: 100,
                                      ),
                                    ),
                                  ),
                                ),
                                // Content
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notification.title,
                                              style: TextStyle(
                                                color: isDarkMode ? Colors.white : const Color(0xFF111827),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (!notification.isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: const BoxDecoration(
                                                color: Colors.redAccent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          Text(
                                            _formatTime(notification.dateCreated),
                                            style: TextStyle(
                                              color: isDarkMode ? Colors.white54 : Colors.black87,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        notification.message,
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white70 : const Color(0xFF374151),
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
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
