import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      } else {
        if (!mounted) return;
        setState(() {
          _error = 'Хатогӣ дар боркунии маълумоти пешсафон.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Хатогӣ дар пайвастшавӣ ба сервер.';
        _isLoading = false;
      });
    }
  }

  String _getRankText(int rank) {
    if (rank == 1) return '1st';
    if (rank == 2) return '2nd';
    if (rank == 3) return '3rd';
    return '${rank}th';
  }

  Widget _buildTopAppBar(bool isBw) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const Text(
            'Рӯйхати пешсафон',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.home_outlined, color: Colors.white, size: 22),
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepPurple[300], size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1E1C24),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTopStatsCard(bool isBw) {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 32),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.emoji_events, color: Colors.amber, size: 36),
                ),
              ),
              IconButton(
                icon: Icon(Icons.reply_outlined, color: Colors.grey[400], size: 24),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1E1C24),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Натиҷаи умумӣ: +$points хол ($averagePercentage%)',
            style: TextStyle(
              color: Colors.deepPurple[400],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey[100], thickness: 1.5),
          const SizedBox(height: 12),
          if (subjectStats.isEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBox('Гурӯҳ', user['groupName'] ?? 'Бе гурӯҳ', Icons.group_outlined),
                _buildStatBox('Холҳои умумӣ', '$points', Icons.military_tech_outlined),
                _buildStatBox('Рейтинг', '#${user['rank']}', Icons.leaderboard_outlined),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'НАТИҶАҲО АЗ РӮИ ФАНҲО:',
                    style: TextStyle(
                      color: Colors.black38,
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
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.deepPurple.withOpacity(0.15), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              subName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF4A148C),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$subPercent%',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$subTest тест / $subPoints хол',
                              style: TextStyle(
                                color: Colors.grey[600],
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

  Widget _buildTabBar(bool isBw) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.deepPurple,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.deepPurple,
        unselectedLabelColor: Colors.grey[400],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        tabs: [
          const Tab(text: 'Топ 10 (Ҳама)'),
          Tab(text: 'Топ 3 (Гурӯҳ $_myGroupName)'),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders(bool isBw) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 36,
            child: Text(
              'Ҷой',
              style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Истифодабаранда',
              style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            'Натиҷа (фоиз)',
            style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(List<dynamic> list, bool isBw) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text(
              'Рӯйхат холӣ аст',
              style: TextStyle(color: Colors.grey),
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
                  ? const Color(0xFFE8F5E9)
                  : (rank == 1
                      ? Colors.amber.withOpacity(0.05)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.green.withOpacity(0.4)
                    : (rank == 1
                        ? Colors.amber.withOpacity(0.3)
                        : Colors.grey[100]!),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    _getRankText(rank),
                    style: TextStyle(
                      color: rank == 1
                          ? Colors.amber[800]
                          : (rank == 2
                              ? Colors.grey[600]
                              : (rank == 3
                                  ? Colors.brown[600]
                                  : Colors.black54)),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.deepPurple[100],
                      backgroundImage: user['imageUrl'] != null && user['imageUrl'].toString().isNotEmpty
                          ? NetworkImage(_getFullImageUrl(user['imageUrl'].toString()))
                          : null,
                      child: user['imageUrl'] != null && user['imageUrl'].toString().isNotEmpty
                          ? null
                          : Text(
                              _getInitials(name),
                              style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                            ),
                    ),
                    if (rank == 1)
                      const Positioned(
                        top: -10,
                        left: 12,
                        child: RotationTransition(
                          turns: AlwaysStoppedAnimation(15 / 360),
                          child: Icon(Icons.star, color: Colors.amber, size: 16),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF1E1C24),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.monetization_on_outlined, color: Colors.amber[700], size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '$points хол',
                            style: TextStyle(
                              color: Colors.amber[800],
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  $groupName',
                            style: TextStyle(
                              color: Colors.grey[500],
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
                  style: const TextStyle(
                    color: Color(0xFF1E1C24),
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
    final isBw = Provider.of<ThemeProvider>(context).isBlackAndWhite;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isBw ? Colors.white : const Color(0xFF0F0C20),
        body: const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: isBw ? Colors.white : const Color(0xFF0F0C20),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.redAccent.withOpacity(0.6)),
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchLeaderboardData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                  child: const Text('Боз кӯшиш кунед', style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isBw
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF311B92),
                    Color(0xFF512DA8),
                  ],
                ),
          color: isBw ? Colors.white : null,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopAppBar(isBw),
              _buildTopStatsCard(isBw),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isBw ? const Color(0xFFF9F9F9) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildTabBar(isBw),
                      _buildColumnHeaders(isBw),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLeaderboardList(_top10Overall, isBw),
                            _buildLeaderboardList(_top3MyGroup, isBw),
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
      ),
    );
  }

  String _getFullImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiService.baseUrl}$url';
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
