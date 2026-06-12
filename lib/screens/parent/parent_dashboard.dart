import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../login_screen.dart';
import '../notifications_feed.dart';
import '../chat/chat_list_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchChildren();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchChildren() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await ApiService.get('/api/parent/children');
      if (response.statusCode == 200) {
        setState(() {
          _children = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showChildStats(int childId, String childName) async {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return FutureBuilder(
              future: ApiService.get('/api/parent/child/$childId/statistics'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: textColor));
                }
                if (snapshot.hasError || snapshot.data?.statusCode != 200) {
                  return Center(child: Text('Хатогӣ дар боркунии омор', style: TextStyle(color: textColor)));
                }

                final stats = jsonDecode(snapshot.data!.body);
                final attempts = stats['testAttempts'] as List;
                final paperResults = stats['paperTestResults'] as List? ?? [];

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: textColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Омори пешрафти $childName',
                      style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    // Quick stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Китобҳои хондашуда',
                            '${stats['booksReadCount']}',
                            Icons.menu_book,
                            textColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Холҳои миёна',
                            '${stats['averageScorePercentage']}%',
                            Icons.analytics,
                            textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Таърихи супоридани тестҳо',
                      style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (attempts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'То ҳол тестҳо супорида нашудаанд',
                            style: TextStyle(color: textColor.withOpacity(0.5)),
                          ),
                        ),
                      )
                    else
                      ...attempts.map((a) {
                        final isGraded = a['isGraded'] ?? true;
                        final percent = (a['percentage'] as num).toDouble();
                        final isPassed = percent >= 50.0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: textColor.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a['testTitle'],
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    if (isGraded)
                                      Text(
                                        'Хол: ${a['score']}/${a['totalQuestions']}',
                                        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13),
                                      )
                                    else
                                      Text(
                                        'Ҷавобҳо қабул шуданд',
                                        style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 13, fontStyle: FontStyle.italic),
                                      ),
                                  ],
                                ),
                              ),
                              if (isGraded)
                                Text(
                                  '${percent.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: isPassed ? Colors.green : Colors.redAccent,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: textColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Дар ҳоли тафтиш',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 24),
                    Text(
                      'Натиҷаҳои тести қоғазӣ',
                      style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (paperResults.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'Натиҷаи тестҳои қоғазӣ мавҷуд нест',
                            style: TextStyle(color: textColor.withOpacity(0.5)),
                          ),
                        ),
                      )
                    else
                      ...paperResults.map((pr) {
                        final subject = pr['subject'] ?? '';
                        final score = pr['score'] ?? 0;
                        final dateStr = pr['dateCreated'] != null 
                            ? DateTime.parse(pr['dateCreated']).toLocal().toString().split(' ')[0] 
                            : '';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: textColor.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subject,
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Сана: $dateStr',
                                      style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$score балл',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenList() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: textColor));
    }

    if (_children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.child_care, size: 64, color: textColor.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'Ҳеҷ кӯдак пайваст карда нашудааст',
                style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Маълумоти кӯдак аз тарафи админ ворид ва таҳрир карда мешавад',
                style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _children.length,
      itemBuilder: (context, index) {
        final child = _children[index];
        final List books = child['books'] ?? [];

        return GestureDetector(
          onTap: () => _showChildStats(child['id'], child['name']),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: textColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isDarkMode ? Colors.white12 : const Color(0xFFEBF3ED),
                          backgroundImage: child['imageUrl'] != null && child['imageUrl'].toString().isNotEmpty
                              ? NetworkImage(ApiService.getFullImageUrl(child['imageUrl'].toString()))
                              : null,
                          child: child['imageUrl'] != null && child['imageUrl'].toString().isNotEmpty
                              ? null
                              : Text(
                                  _getInitials(child['name'] ?? ''),
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : const Color(0xFF1E7431),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child['name'],
                              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              child['email'],
                              style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward_ios, color: textColor.withOpacity(0.3), size: 16),
                  ],
                ),
                const Divider(height: 32, thickness: 1),
                Text(
                  'Китобҳои дастрасшуда (${books.length}):',
                  style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                books.isEmpty
                    ? Text('Ҳеҷ китоб дастрас нест.', style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 13))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: books.map((b) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: textColor.withOpacity(0.1)),
                            ),
                            child: Text(
                              b['title'],
                              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _logout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parent = Provider.of<AuthProvider>(context).currentUser;
    final parentName = parent?.name ?? 'Волидайн';
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: textColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parentName,
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Панели назорати волидайн',
              style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: textColor,
          labelColor: textColor,
          unselectedLabelColor: textColor.withOpacity(0.4),
          tabs: const [
            Tab(text: 'Кӯдакони ман'),
            Tab(text: 'Паёмҳо'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChildrenList(),
          const NotificationsFeedScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChatListScreen()),
          );
        },
        backgroundColor: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431),
        child: Icon(
          Icons.chat_bubble_outline,
          color: isDarkMode ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
