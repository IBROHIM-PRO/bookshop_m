import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/test_model.dart';
import '../../models/book.dart';
import '../../providers/theme_provider.dart';
import 'leaderboard_screen.dart';

class ReaderStatsScreen extends StatefulWidget {
  const ReaderStatsScreen({super.key});

  @override
  State<ReaderStatsScreen> createState() => _ReaderStatsScreenState();
}

class _ReaderStatsScreenState extends State<ReaderStatsScreen> {
  bool _isLoading = true;
  String? _error;
  List<TestAttemptModel> _attempts = [];
  int _booksCount = 0;
  double _averageScore = 0.0;
  int _dailyStreak = 0;
  List<bool> _weeklyStreakDays = [false, false, false, false, false, false, false];
  List<double> _lessonsLearned = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  String _activePreset = '1W';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _fetchStatsData();
  }

  Future<void> _fetchStatsData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String url = '/api/stats/dashboard';
      if (_customStartDate != null && _customEndDate != null) {
        final startIso = _customStartDate!.toUtc().toIso8601String();
        final endIso = _customEndDate!.toUtc().toIso8601String();
        url += '?startDate=$startIso&endDate=$endIso';
      } else {
        url += '?preset=$_activePreset';
      }

      final response = await ApiService.get(url);
      debugPrint('GET $url -> status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List attemptsJson = data['testAttempts'] ?? [];
        final attempts = attemptsJson.map((a) => TestAttemptModel.fromJson(a)).toList();

        final List<dynamic> weeklyStreakJson = data['weeklyStreakDays'] ?? [];
        final weeklyStreak = weeklyStreakJson.map((x) => x as bool).toList();

        final List<dynamic> lessonsLearnedJson = data['lessonsLearned'] ?? [];
        final lessons = lessonsLearnedJson.map((x) => (x as num).toDouble()).toList();

        if (!mounted) return;
        setState(() {
          _attempts = attempts;
          _booksCount = data['booksCount'] ?? 0;
          _averageScore = (data['averageScore'] ?? 0.0).toDouble();
          _dailyStreak = data['dailyStreak'] ?? 0;
          _weeklyStreakDays = weeklyStreak.length == 7 ? weeklyStreak : [false, false, false, false, false, false, false];
          _lessonsLearned = lessons.length == 7 ? lessons : [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        String msg = 'Хатогӣ дар боркунии маълумот.';
        if (response.statusCode == 401) {
          msg = 'Сессия ба охир расид. Лутфан аз нав ворид шавед.';
        } else if (response.body.isNotEmpty) {
          try {
            final resData = jsonDecode(response.body);
            if (resData['message'] != null) {
              msg = resData['message'];
            }
          } catch (_) {}
        }
        setState(() {
          _error = msg;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Stats fetch error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Хатогӣ дар пайвастшавӣ ба сервер: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _selectPreset(String preset) {
    setState(() {
      _customStartDate = null;
      _customEndDate = null;
      _activePreset = preset;
    });
    _fetchStatsData();
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final initialDateRange = DateTimeRange(
      start: _customStartDate ?? DateTime.now().subtract(const Duration(days: 7)),
      end: _customEndDate ?? DateTime.now(),
    );
    
    final newDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6B4FB3),
              onPrimary: Colors.white,
              surface: Color(0xFF15102A),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F0C20),
          ),
          child: child!,
        );
      },
    );

    if (newDateRange != null) {
      setState(() {
        _customStartDate = newDateRange.start;
        _customEndDate = DateTime(newDateRange.end.year, newDateRange.end.month, newDateRange.end.day, 23, 59, 59);
        _activePreset = 'custom';
      });
      _fetchStatsData();
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _presetNameTajik(String preset) {
    switch (preset) {
      case '1D': return '1 Рӯз';
      case '1W': return '1 Ҳафта';
      case '1M': return '1 Моҳ';
      case '6M': return '6 Моҳ';
      case '1Y': return '1 Сол';
      default: return '1 Ҳафта';
    }
  }

  DateTime _getStartOfWeek() {
    final today = DateTime.now();
    final diff = today.weekday % 7;
    return today.subtract(Duration(days: diff));
  }

  double _getBarHeight(double val, double maxVal) {
    if (maxVal == 0) return 10.0;
    return (val / maxVal) * 100.0 + 10.0;
  }

  @override
  Widget build(BuildContext context) {
    final isBw = Provider.of<ThemeProvider>(context).isBlackAndWhite;
    final theme = Theme.of(context);
    final textColor = isBw ? Colors.black : Colors.white;
    final subTextColor = isBw ? Colors.black54 : Colors.white.withOpacity(0.5);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.redAccent.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: textColor)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchStatsData,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Боз кӯшиш кунед',
                style: TextStyle(color: isBw ? Colors.black : Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final pageBgColor = isBw ? Colors.white : theme.scaffoldBackgroundColor;

    // Concentric progress math
    final double booksProgress = (_booksCount / 10.0).clamp(0.0, 1.0);
    final double testsProgress = (_attempts.length / 10.0).clamp(0.0, 1.0);
    final double avgScoreProgress = (_averageScore / 100.0).clamp(0.0, 1.0);

    // Scaling for weekly bar chart
    double maxVal = _lessonsLearned.reduce((a, b) => a > b ? a : b);
    if (maxVal < 1.0) maxVal = 1.0;

    final startOfWeek = _getStartOfWeek();

    return Container(
      color: pageBgColor,
      child: RefreshIndicator(
        onRefresh: _fetchStatsData,
        color: theme.colorScheme.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Пешрафт',
                      style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (_activePreset == 'custom' && _customStartDate != null && _customEndDate != null)
                      Text(
                        '${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)}',
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      )
                    else
                      Text(
                        'Давраи фаъол: ${_presetNameTajik(_activePreset)}',
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _selectCustomDateRange(context),
                  child: _buildCircleHeaderButton(Icons.calendar_month, isBw),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Daily Streak Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Пешрафти рӯзона (Daily Streak)',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_dailyStreak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$_dailyStreak рӯз',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Daily Streak Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isBw ? const Color(0xFFF5F5F5) : const Color(0xFF6B4FB3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStreakDayName('Sun', isBw),
                      _buildStreakDayName('Mon', isBw),
                      _buildStreakDayName('Tue', isBw),
                      _buildStreakDayName('Wed', isBw),
                      _buildStreakDayName('Thu', isBw),
                      _buildStreakDayName('Fri', isBw),
                      _buildStreakDayName('Sat', isBw),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (index) {
                      final dayDate = startOfWeek.add(Duration(days: index));
                      final completed = _weeklyStreakDays.length > index ? _weeklyStreakDays[index] : false;
                      return _buildStreakCircle(completed, dayDate.day.toString(), isBw);
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Lesson Learned Title
            Text(
              'Дарсҳои омӯхташуда',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Lesson Learned Bar Chart
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isBw ? const Color(0xFFF9F9F9) : Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isBw ? Colors.black12 : Colors.white.withOpacity(0.04)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${maxVal.toStringAsFixed(0)}', style: TextStyle(color: subTextColor, fontSize: 11)),
                      const SizedBox(height: 12),
                      Text('${(maxVal * 0.75).toStringAsFixed(0)}', style: TextStyle(color: subTextColor, fontSize: 11)),
                      const SizedBox(height: 12),
                      Text('${(maxVal * 0.5).toStringAsFixed(0)}', style: TextStyle(color: subTextColor, fontSize: 11)),
                      const SizedBox(height: 12),
                      Text('${(maxVal * 0.25).toStringAsFixed(0)}', style: TextStyle(color: subTextColor, fontSize: 11)),
                      const SizedBox(height: 12),
                      Text('0', style: TextStyle(color: subTextColor, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (index) {
                        final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                        final dayName = daysOfWeek[index];
                        final todayNameIndex = DateTime.now().weekday % 7;
                        final isToday = index == todayNameIndex;
                        final val = _lessonsLearned.length > index ? _lessonsLearned[index] : 0.0;
                        final height = _getBarHeight(val, maxVal);
                        return _buildBar(height, dayName, isToday, isBw);
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Subject Mastery Title
            Text(
              'Дараҷаи азхудкунӣ',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Segmented pills
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => _selectPreset('1D'),
                  child: _buildFilterPill('1D', _activePreset == '1D', isBw),
                ),
                GestureDetector(
                  onTap: () => _selectPreset('1W'),
                  child: _buildFilterPill('1W', _activePreset == '1W', isBw),
                ),
                GestureDetector(
                  onTap: () => _selectPreset('1M'),
                  child: _buildFilterPill('1M', _activePreset == '1M', isBw),
                ),
                GestureDetector(
                  onTap: () => _selectPreset('6M'),
                  child: _buildFilterPill('6M', _activePreset == '6M', isBw),
                ),
                GestureDetector(
                  onTap: () => _selectPreset('1Y'),
                  child: _buildFilterPill('1Y', _activePreset == '1Y', isBw),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Concentric Rings & Legend Row
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SizedBox(
                      width: 170,
                      height: 170,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer: Китобҳо (Green)
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: booksProgress == 0 ? 0.05 : booksProgress,
                              strokeWidth: 14,
                              backgroundColor: Colors.green.withOpacity(0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                          // Middle: Тестҳо (Yellow/Orange)
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: testsProgress == 0 ? 0.05 : testsProgress,
                              strokeWidth: 14,
                              backgroundColor: Colors.amber.withOpacity(0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                            ),
                          ),
                          // Inner: Баҳо (Red/Rose)
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              value: avgScoreProgress == 0 ? 0.05 : avgScoreProgress,
                              strokeWidth: 14,
                              backgroundColor: Colors.redAccent.withOpacity(0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(Colors.green, 'Китобҳо ($_booksCount)', isBw),
                      const SizedBox(height: 16),
                      _buildLegendItem(Colors.amber, 'Тестҳо (${_attempts.length})', isBw),
                      const SizedBox(height: 16),
                      _buildLegendItem(Colors.redAccent, 'Баҳо (${_averageScore.toStringAsFixed(0)}%)', isBw),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Attempt History Title
            Text(
              'Таърихи тестҳо',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (_attempts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'Шумо то ҳол ягон тест насупоридаед',
                    style: TextStyle(color: subTextColor, fontSize: 14),
                  ),
                ),
              )
            else
              ..._attempts.map((attempt) {
                final isPassed = attempt.percentage >= 50.0;
                final scoreColor = isBw
                    ? Colors.black
                    : (isPassed ? Colors.teal : Colors.redAccent);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isBw ? const Color(0xFFF5F5F5) : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isBw ? Colors.black12 : Colors.white.withOpacity(0.04)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attempt.testTitle,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Сана: ${attempt.dateCreatedTajik}',
                              style: TextStyle(color: subTextColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (attempt.isGraded) ...[
                            Text(
                              '${attempt.score}/${attempt.totalQuestions}',
                              style: TextStyle(
                                color: scoreColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${attempt.percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: isBw ? Colors.black54 : scoreColor.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isBw ? Colors.grey : Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Дар ҳоли тафтиш',
                                style: TextStyle(
                                  color: isBw ? Colors.black : Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                );
              },
              icon: const Icon(Icons.emoji_events, color: Colors.white, size: 20),
              label: const Text(
                'Рейтинг (Топ 10 ва Топ 3)',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isBw ? Colors.black : const Color(0xFF6B4FB3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleHeaderButton(IconData icon, bool isBw) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: isBw ? Colors.black12 : Colors.white.withOpacity(0.15)),
      ),
      child: Center(
        child: Icon(icon, color: isBw ? Colors.black87 : Colors.white70, size: 18),
      ),
    );
  }

  Widget _buildStreakDayName(String name, bool isBw) {
    return Text(
      name,
      style: TextStyle(
        color: isBw ? Colors.black54 : Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildStreakCircle(bool completed, String dayNum, bool isBw) {
    final activeColor = isBw ? Colors.black : const Color(0xFF6B4FB3);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: completed
            ? Colors.green
            : (isBw ? Colors.white : Colors.white.withOpacity(0.9)),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: completed
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                dayNum,
                style: TextStyle(
                  color: completed ? Colors.white : activeColor.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildBar(double height, String day, bool isToday, bool isBw) {
    final barColor = isBw ? Colors.black87 : const Color(0xFF6B4FB3);
    return Column(
      children: [
        Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            color: isToday
                ? (isBw ? Colors.black : const Color(0xFF6B4FB3))
                : (isBw ? Colors.black54 : Colors.grey),
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String label, bool isSelected, bool isBw) {
    final primaryColor = isBw ? Colors.black : const Color(0xFF6B4FB3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? primaryColor.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? primaryColor : (isBw ? Colors.black54 : Colors.grey),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, bool isBw) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isBw ? Colors.black87 : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

extension on TestAttemptModel {
  String get dateCreatedTajik {
    final year = dateTaken.year;
    final month = dateTaken.month.toString().padLeft(2, '0');
    final day = dateTaken.day.toString().padLeft(2, '0');
    final hour = dateTaken.hour.toString().padLeft(2, '0');
    final minute = dateTaken.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }
}
