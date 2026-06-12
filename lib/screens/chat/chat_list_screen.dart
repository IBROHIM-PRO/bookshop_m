import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_snackbar.dart';
import '../../services/websocket_service.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<dynamic> _contacts = [];
  bool _isLoading = true;
  StreamSubscription? _wsSubscription;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _wsSubscription = WebSocketService().messageStream.listen((data) {
      final type = data['type'] as String?;
      if (type == 'chat_message' || type == 'chat_message_edit' || type == 'chat_message_delete') {
        _fetchContacts(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<void> _fetchContacts({bool showLoading = true}) async {
    if (showLoading || _contacts.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await ApiService.get('/api/chat/contacts');
      if (response.statusCode == 200) {
        setState(() {
          _contacts = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        AppSnackBar.show(context, message: 'Хатогӣ дар боргирии рӯйхат', type: SnackBarType.error);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      AppSnackBar.show(context, message: 'Мушкилии пайвастшавӣ ба сервер', type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final theme = Theme.of(context);
    final primaryColor = isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431);
    final bgColor = theme.scaffoldBackgroundColor;

    final filteredContacts = _contacts.where((contact) {
      final name = (contact['name'] ?? '').toString().toLowerCase();
      final email = (contact['email'] ?? '').toString().toLowerCase();
      final studentName = (contact['studentName'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query) || studentName.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                'Чат',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF161E18) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: BorderSide(
                    color: isDarkMode ? textColor.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Ҷустуҷӯ...',
                    hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                    prefixIcon: Icon(Icons.search, color: textColor.withOpacity(0.4)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 8),

            // Contact List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchContacts(showLoading: true),
                color: primaryColor,
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: primaryColor))
                    : filteredContacts.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _searchQuery.isNotEmpty ? Icons.search_off : Icons.chat_bubble_outline,
                                      size: 64,
                                      color: textColor.withOpacity(0.2),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'Натиҷае ёфт нашуд'
                                          : 'Ягон сӯҳбат ёфт нашуд',
                                      style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredContacts.length,
                            itemBuilder: (context, index) {
                              final contact = filteredContacts[index];
                              final name = contact['name'] ?? 'Истифодабаранда';
                              final role = contact['role'] ?? '';
                              final studentName = contact['studentName'] ?? '';
                              final unreadCount = contact['unreadCount'] ?? 0;
                              final imageUrl = contact['imageUrl'] as String?;

                              return InkWell(
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChatDetailScreen(
                                        contactId: contact['id'],
                                        contactName: name,
                                        studentName: studentName,
                                        contactRole: role,
                                      ),
                                    ),
                                  );
                                  _fetchContacts(showLoading: false);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Row(
                                    children: [
                                      // Avatar with dot
                                      Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor: primaryColor.withOpacity(0.1),
                                            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                                                ? NetworkImage(ApiService.getFullImageUrl(imageUrl))
                                                : null,
                                            child: imageUrl != null && imageUrl.isNotEmpty
                                                ? null
                                                : Text(
                                                    _getInitials(name),
                                                    style: TextStyle(
                                                      color: primaryColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: primaryColor,
                                                shape: BoxShape.circle,
                                                border: BorderSide(
                                                  color: bgColor,
                                                  width: 2.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      // Name & Subtitle
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              studentName.isNotEmpty
                                                  ? (role == 'Teacher' ? 'Муаллими: $studentName' : 'Волидайни: $studentName')
                                                  : (role == 'Teacher' ? 'Муаллим' : 'Волидайн'),
                                              style: TextStyle(
                                                color: textColor.withOpacity(0.5),
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Trailing Info (Unread Count)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (unreadCount > 0)
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: primaryColor,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '$unreadCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
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
      ),
    );
  }
}
