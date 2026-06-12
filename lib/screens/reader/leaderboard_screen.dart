import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../providers/theme_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _top10Overall = [];
  List<dynamic> _top3MyGroup = [];

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _fetchLeaderboardData();
  }

  Future<void> _fetchLeaderboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _fetchWithRetry();
  }

  Future<void> _fetchWithRetry() async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        final response = await ApiService.get('/api/leaderboard');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (!mounted) return;
          setState(() {
            _top10Overall = data['top10Overall'] ?? [];
            _top3MyGroup = data['top3MyGroup'] ?? [];
            _isLoading = false;
          });
          return;
        } else {
          attempt++;
          if (attempt < _maxRetries) {
            await Future.delayed(_retryDelay);
          }
        }
      } catch (e) {
        attempt++;
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay);
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _error = 'Хатогӣ дар пайвастшавӣ ба сервер. Лутфан баъд аз каме кӯшиш кунед.';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF1F8F4);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF1E7431))),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _fetchLeaderboardData,
                  child: const Text('Боз кӯшиш кунед'),
                )
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Топ студент',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: TabBar(
            indicatorColor: const Color(0xFF1E7431),
            labelColor: const Color(0xFF1E7431),
            unselectedLabelColor: isDarkMode ? Colors.white54 : Colors.grey,
            tabs: const [
              Tab(text: 'Топ 10'),
              Tab(text: 'Топ 3 гурӯҳ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(_top10Overall, isDarkMode),
            _buildList(_top3MyGroup, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<dynamic> list, bool isDarkMode) {
    return RefreshIndicator(
      onRefresh: _fetchLeaderboardData,
      color: const Color(0xFF1E7431),
      child: list.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'Рӯйхат холӣ аст',
                    style: TextStyle(color: Colors.grey.withOpacity(0.8)),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final user = list[index];
                final rank = user['rank'] ?? (index + 1);
                final name = user['name'] ?? '';
                final percentage = user['averagePercentage'] ?? 0.0;
                final subtitle = user['groupName'] ?? 'Бе гурӯҳ';

                Color borderColor;
                Color shadowColor;
                Color rankColor;
                double borderWidth = 1.5;

                if (rank == 1) {
                  borderColor = const Color(0xFFFFC107); // Gold
                  shadowColor = const Color(0xFFFFC107).withOpacity(0.3);
                  rankColor = const Color(0xFFFFC107);
                } else if (rank == 2) {
                  borderColor = Colors.grey; // Silver
                  shadowColor = Colors.grey.withOpacity(0.3);
                  rankColor = Colors.grey;
                } else if (rank == 3) {
                  borderColor = const Color(0xFFCD7F32); // Bronze
                  shadowColor = const Color(0xFFCD7F32).withOpacity(0.3);
                  rankColor = const Color(0xFFCD7F32);
                } else {
                  borderColor = const Color(0xFF4CAF50); // Green
                  shadowColor = Colors.transparent;
                  borderWidth = 1.0;
                  rankColor = Colors.transparent;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: borderWidth),
                    boxShadow: shadowColor != Colors.transparent && !isDarkMode ? [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ] : null,
                  ),
                  child: Row(
                    children: [
                      if (rank <= 3) ...[
                        SizedBox(
                          width: 30,
                          child: Center(
                            child: Text(
                              '$rank',
                              style: TextStyle(
                                color: rankColor,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 1.0),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.transparent,
                          backgroundImage: user['imageUrl'] != null && user['imageUrl'].toString().isNotEmpty
                              ? CachedNetworkImageProvider(ApiService.getFullImageUrl(user['imageUrl'].toString()))
                              : null,
                          child: user['imageUrl'] != null && user['imageUrl'].toString().isNotEmpty
                              ? null
                              : Text(
                                  _getInitials(name),
                                  style: TextStyle(color: borderColor, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDarkMode ? Colors.white54 : Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                    ],
                  ),
                );
              },
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
