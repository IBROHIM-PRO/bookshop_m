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

  // Retry logic
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

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
    await _fetchWithRetry();
  }

  Future<void> _fetchWithRetry() async {
    int attempt = 0;
    while (attempt < _maxRetries) {
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
          return;
        } else {
          attempt++;
          if (attempt < _maxRetries) {
            await Future.delayed(_retryDelay);
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
        }
      } catch (e) {
        attempt++;
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay);
        } else {
          if (!mounted) return;
          setState(() {
            _error = 'Хатогӣ дар пайвастшавӣ ба сервер';
            _isLoading = false;
          });
        }
      }
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
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
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
            colorScheme: isDarkMode ? const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ) : const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
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
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final theme = Theme.of(context);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = textColor.withOpacity(0.5);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: textColor));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: textColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: textColor)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchStatsData,
              child: const Text('Боз кӯшиш кунед'),
            ),
          ],
        ),
      );
    }

    final pageBgColor = theme.scaffoldBackgroundColor;

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
        color: textColor,
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
                  child: _buildCircleHeaderButton(Icons.calendar_month, isDarkMode, textColor),
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
                      color: textColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: textColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.local_fire_department, color: textColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$_dailyStreak рӯз',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
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
                color: textColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: textColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStreakDayName('Sun', subTextColor),
                      _buildStreakDayName('Mon', subTextColor),
                      _buildStreakDayName('Tue', subTextColor),
                      _buildStreakDayName('Wed', subTextColor),
                      _buildStreakDayName('Thu', subTextColor),
                      _buildStreakDayName('Fri', subTextColor),
                      _buildStreakDayName('Sat', subTextColor),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (index) {
                      final dayDate = startOfWeek.add(Duration(days: index));
                      final completed = _weeklyStreakDays.length > index ? _weeklyStreakDays[index] : false;
                      return _buildStreakCircle(completed, dayDate.day.toString(), textColor, isDarkMode ? Colors.black : Colors.white);
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
                color: textColor.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: textColor.withOpacity(0.1)),
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
                        return _buildBar(height, dayName, isToday, index);
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
                  child: _buildFilterPill('1D', _activePreset == '1D', textColor),
                ),
                GestureDetector(
                  onTap: () => _selectPreset('1W'),
                  child: _buildFilterPill('1W', _activePreset == '1W', textColor),
                ),
                GestureDetector(
                  onTap: () => _selectPreset('1M'),
                  child: _buildFilterPill('1M', _activePreset == '1M', textColor),
                ),
                GestureDetector(
                  onTap: () => _selectPreset('6M'),
                  child: _buildFilterPill('6M', _activePreset == '6M', textColor),
                ),
                GestureDetector(
                  onTap: () => _selectPreset('1Y'),
                  child: _buildFilterPill('1Y', _activePreset == '1Y', textColor),
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
                           // Outer: Китобҳо (Brand Green)
                           SizedBox(
                             width: 160,
                             height: 160,
                             child: CircularProgressIndicator(
                               value: booksProgress == 0 ? 0.05 : booksProgress,
                               strokeWidth: 14,
                               backgroundColor: isDarkMode ? Colors.white10 : const Color(0xFFEBF3ED),
                               valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E7431)),
                             ),
                           ),
                           // Middle: Тестҳо (Light Green)
                           SizedBox(
                             width: 120,
                             height: 120,
                             child: CircularProgressIndicator(
                               value: testsProgress == 0 ? 0.05 : testsProgress,
                               strokeWidth: 14,
                               backgroundColor: isDarkMode ? Colors.white10 : const Color(0xFFEBF3ED),
                               valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA3E635)),
                             ),
                           ),
                           // Inner: Баҳо (Gold)
                           SizedBox(
                             width: 80,
                             height: 80,
                             child: CircularProgressIndicator(
                               value: avgScoreProgress == 0 ? 0.05 : avgScoreProgress,
                               strokeWidth: 14,
                               backgroundColor: isDarkMode ? Colors.white10 : const Color(0xFFEBF3ED),
                               valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
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
                       _buildLegendItem(const Color(0xFF1E7431), 'Китобҳо ($_booksCount)', textColor),
                       const SizedBox(height: 16),
                       _buildLegendItem(const Color(0xFFA3E635), 'Тестҳо (${_attempts.length})', textColor),
                       const SizedBox(height: 16),
                       _buildLegendItem(const Color(0xFFF59E0B), 'Баҳо (${_averageScore.toStringAsFixed(0)}%)', textColor),
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
                final cardColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
                final borderColor = isDarkMode ? textColor.withOpacity(0.1) : const Color(0xFF1E7431).withOpacity(0.15);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: isDarkMode ? [] : [
                      BoxShadow(
                        color: const Color(0xFF228B22).withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
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
                              '${attempt.earnedPoints}/${attempt.totalPoints} хол',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${attempt.percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: isPassed ? FontWeight.bold : FontWeight.normal,
                                decoration: isPassed ? null : TextDecoration.lineThrough,
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: textColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: textColor.withOpacity(0.2)),
                              ),
                              child: Text(
                                'Дар ҳоли тафтиш',
                                style: TextStyle(
                                  color: textColor,
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
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                  );
                },
                icon: Icon(Icons.emoji_events_outlined, color: isDarkMode ? Colors.black : Colors.white, size: 20),
                label: const Text(
                  'Рейтинг (Топ 10 ва Топ 3)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleHeaderButton(IconData icon, bool isDarkMode, Color textColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Center(
        child: Icon(icon, color: textColor, size: 18),
      ),
    );
  }

  Widget _buildStreakDayName(String name, Color subTextColor) {
    return Text(
      name,
      style: TextStyle(
        color: subTextColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildStreakCircle(bool completed, String dayNum, Color textColor, Color bgColor) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: completed ? textColor : bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Center(
        child: completed
            ? Icon(Icons.check, color: bgColor, size: 18)
            : Text(
                dayNum,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildBar(double height, String day, bool isToday, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color barColor;
    if (isDarkMode) {
      barColor = isToday ? const Color(0xFF1E7431) : Colors.white24;
    } else {
      if (isToday) {
        barColor = const Color(0xFF1E7431);
      } else {
        barColor = (index % 2 == 0) ? const Color(0xFFA3E635) : const Color(0xFFF59E0B);
      }
    }

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
                ? (isDarkMode ? Colors.white : const Color(0xFF1E7431))
                : (isDarkMode ? Colors.white54 : const Color(0xFF657367)),
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String label, bool isSelected, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? textColor : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.1)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white) : textColor.withOpacity(0.6),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, Color textColor) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: textColor.withOpacity(0.2))),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: textColor,
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
