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

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  String _myGroupName = 'Муайян нашудааст';
  int _myRank = 0;
  int _myPoints = 0;
  List<dynamic> _top10Overall = [];
  List<dynamic> _top3MyGroup = [];

  // Selected student for the top dashboard card
  dynamic _selectedUser;

  // Retry logic
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchLeaderboardData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      final list = _tabController.index == 0 ? _top10Overall : _top3MyGroup;
      if (list.isNotEmpty) {
        setState(() {
          _selectedUser = list.first;
        });
      }
    }
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
            _myGroupName = data['myGroupName'] ?? 'Муайян нашудааст';
            _myRank = data['myRank'] ?? 0;
            _myPoints = data['myPoints'] ?? 0;
            _top10Overall = data['top10Overall'] ?? [];
            _top3MyGroup = data['top3MyGroup'] ?? [];

            final currentList = _tabController.index == 0 ? _top10Overall : _top3MyGroup;
            if (currentList.isNotEmpty) {
              _selectedUser = currentList.first;
            }

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

  String _getRankText(int rank) {
    if (rank == 1) return '1st';
    if (rank == 2) return '2nd';
    if (rank == 3) return '3rd';
    return '${rank}th';
  }

  Widget _buildTopAppBar(bool isDarkMode, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(right: 48), // Offset back button to center title
                child: Text(
                  'Рӯйхати пешсафон',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color textColor, bool isDarkMode) {
    return Column(
      children: [
        Icon(
          icon, 
          color: isDarkMode ? textColor.withOpacity(0.5) : const Color(0xFF1E7431), 
          size: 24
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isDarkMode ? textColor.withOpacity(0.4) : const Color(0xFF657367),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTopStatsCard(bool isDarkMode, Color textColor) {
    if (_selectedUser == null) {
      return const SizedBox.shrink();
    }

    final user = _selectedUser!;
    final name = user['name'] ?? '';
    final points = user['totalPoints'] ?? 0;
    final averagePercentage = user['averagePercentage'] ?? 0.0;
    final subjectStats = user['subjectStats'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDarkMode ? textColor.withOpacity(0.1) : const Color(0xFFD1E2D5),
        ),
        boxShadow: isDarkMode ? [] : [
          BoxShadow(
            color: const Color(0xFF228B22).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDarkMode ? textColor.withOpacity(0.05) : const Color(0xFFEBF3ED),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDarkMode ? textColor.withOpacity(0.1) : const Color(0xFFD1E2D5),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.emoji_events_outlined, 
                    color: isDarkMode ? textColor : const Color(0xFF1E7431), 
                    size: 36
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Натиҷаи умумӣ: ($averagePercentage%)',
            style: TextStyle(
              color: isDarkMode ? textColor.withOpacity(0.6) : const Color(0xFF657367),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            color: isDarkMode ? textColor.withOpacity(0.1) : const Color(0xFFD1E2D5), 
            thickness: 1.5
          ),
          const SizedBox(height: 12),
          if (subjectStats.isEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBox('Гурӯҳ', user['groupName'] ?? 'Бе гурӯҳ', Icons.group_outlined, textColor, isDarkMode),
                _buildStatBox('Холҳо', '$points', Icons.military_tech_outlined, textColor, isDarkMode),
                _buildStatBox('Рейтинг', '#${user['rank']}', Icons.leaderboard_outlined, textColor, isDarkMode),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'НАТИҶАҲО АЗ РӮИ ФАНҲО:',
                    style: TextStyle(
                      color: isDarkMode ? textColor.withOpacity(0.4) : const Color(0xFF657367),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                SizedBox(
                  height: 85,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: subjectStats.length,
                    itemBuilder: (context, i) {
                      final stat = subjectStats[i];
                      final subName = stat['subjectName'] ?? 'Фан';
                      final subPercent = stat['averageScorePercent'] ?? 0.0;
                      final subPoints = stat['earnedPoints'] ?? 0;
                      final subTests = stat['totalTests'] ?? 0;

                      return Container(
                        width: 135,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode ? textColor.withOpacity(0.05) : const Color(0xFFEBF3ED),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDarkMode ? textColor.withOpacity(0.1) : const Color(0xFFD1E2D5), 
                            width: 1.2
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              subName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDarkMode ? textColor : const Color(0xFF1A1F1C),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$subPercent%',
                              style: TextStyle(
                                color: isDarkMode ? textColor : const Color(0xFF1E7431),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$subTests тест / $subPoints хол',
                              style: TextStyle(
                                color: isDarkMode ? textColor.withOpacity(0.5) : const Color(0xFF657367),
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDarkMode, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: TabBar(
        controller: _tabController,
        indicatorColor: textColor,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: textColor,
        unselectedLabelColor: textColor.withOpacity(0.4),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: [
          const Tab(text: 'Топ 10 (Ҳама)'),
          Tab(text: 'Топ 3 ($_myGroupName)'),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              'Ҷой',
              style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Истифодабаранда',
              style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            'Натиҷа (%)',
            style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(List<dynamic> list, bool isDarkMode, Color textColor) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 48, color: textColor.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text(
              'Рӯйхат холӣ аст',
              style: TextStyle(color: textColor.withOpacity(0.4)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final user = list[index];
        final rank = user['rank'] ?? (index + 1);
        final name = user['name'] ?? '';
        final points = user['totalPoints'] ?? 0;
        final percentage = user['averagePercentage'] ?? 0.0;
        final groupName = user['groupName'] ?? 'Бе гурӯҳ';

        final isSelected = _selectedUser != null && _selectedUser!['id'] == user['id'];

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedUser = user;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? textColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? textColor
                    : textColor.withOpacity(0.05),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    _getRankText(rank),
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: textColor.withOpacity(0.1),
                  backgroundImage: user['imageUrl'] != null && user['imageUrl'].toString().isNotEmpty
                      ? CachedNetworkImageProvider(_getFullImageUrl(user['imageUrl'].toString()))
                      : null,
                  child: user['imageUrl'] != null && user['imageUrl'].toString().isNotEmpty
                      ? null
                      : Text(
                          _getInitials(name),
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [                        
                          Text(
                            '$points хол',
                            style: TextStyle(
                              color: textColor.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  $groupName',
                            style: TextStyle(
                              color: textColor.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: textColor)),
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
                Icon(Icons.error_outline, size: 60, color: textColor.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: textColor)),
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

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: RefreshIndicator(
        onRefresh: _fetchLeaderboardData,
        color: textColor,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF15102A) : const Color(0xFF1E7431),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildTopAppBar(isDarkMode, context),
                    _buildTopStatsCard(isDarkMode, isDarkMode ? Colors.white : const Color(0xFF1A1F1C)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: backgroundColor,
                child: Column(
                  children: [
                    _buildTabBar(isDarkMode, textColor),
                    _buildColumnHeaders(textColor),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildLeaderboardList(_top10Overall, isDarkMode, textColor),
                          _buildLeaderboardList(_top3MyGroup, isDarkMode, textColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFullImageUrl(String? url) {
    return ApiService.getFullImageUrl(url);
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
