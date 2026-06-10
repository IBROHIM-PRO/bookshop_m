import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/test_model.dart';
import '../../models/paper_test_model.dart';
import '../../services/api_service.dart';
import '../../providers/theme_provider.dart';
import 'test_quiz.dart';

class ReaderTestsScreen extends StatefulWidget {
  const ReaderTestsScreen({super.key});

  @override
  State<ReaderTestsScreen> createState() => _ReaderTestsScreenState();
}

class _ReaderTestsScreenState extends State<ReaderTestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TestModel> _tests = [];
  List<TestAttemptModel> _attempts = [];
  List<PaperTestResultModel> _paperResults = [];
  bool _isLoading = true;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchTestData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTestData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchWithRetry();
  }

  Future<void> _fetchWithRetry() async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        final testsResponse = await ApiService.get('/api/tests');
        final attemptsResponse = await ApiService.get('/api/tests/attempts');
        final paperResponse = await ApiService.get('/api/tests/paper');

        if (testsResponse.statusCode == 200 && attemptsResponse.statusCode == 200 && paperResponse.statusCode == 200) {
          final List testsJson = jsonDecode(testsResponse.body);
          final List attemptsJson = jsonDecode(attemptsResponse.body);
          final List paperJson = jsonDecode(paperResponse.body);

          if (!mounted) return;
          setState(() {
            _tests = testsJson.map((t) => TestModel.fromJson(t)).toList();
            _attempts = attemptsJson.map((a) => TestAttemptModel.fromJson(a)).toList();
            _paperResults = paperJson.map((p) => PaperTestResultModel.fromJson(p)).toList();
            _isLoading = false;
          });
          return;
        } else {
          attempt++;
          if (attempt < _maxRetries) {
            await Future.delayed(_retryDelay);
          } else {
            if (!mounted) return;
            setState(() {
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
            _isLoading = false;
          });
        }
      }
    }
  }

  Widget _buildTestsList(Color textColor, bool isDarkMode) {
    if (_tests.isEmpty) {
      return Center(
        child: Text(
          'Тестҳо айни замон дастрас нестанд',
          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 16),
        ),
      );
    }

    final cardColor = Theme.of(context).cardColor;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tests.length,
      itemBuilder: (context, index) {
        final test = _tests[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFD1E2D5)),
            boxShadow: isDarkMode ? [] : [
              BoxShadow(
                color: const Color(0xFF228B22).withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                test.title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (test.description != null && test.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  test.description!,
                  style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline, color: textColor.withOpacity(0.7), size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '${test.questionCount} савол',
                        style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 14),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TestQuizScreen(testId: test.id, testTitle: test.title),
                        ),
                      ).then((_) => _fetchTestData());
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Сар кардан', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttemptsList(Color textColor, bool isDarkMode) {
    if (_attempts.isEmpty) {
      return Center(
        child: Text(
          'Шумо то ҳол ягон тест насупоридаед',
          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 16),
        ),
      );
    }

    final cardColor = Theme.of(context).cardColor;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _attempts.length,
      itemBuilder: (context, index) {
        final attempt = _attempts[index];
        final isPassed = attempt.percentage >= 50.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFD1E2D5)),
            boxShadow: isDarkMode ? [] : [
              BoxShadow(
                color: const Color(0xFF228B22).withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                      style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${attempt.score}/${attempt.totalQuestions}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${attempt.percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: isPassed ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaperResultsList(Color textColor, bool isDarkMode) {
    if (_paperResults.isEmpty) {
      return Center(
        child: Text(
          'Натиҷаи тестҳои қоғазӣ мавҷуд нест',
          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 16),
        ),
      );
    }

    final cardColor = Theme.of(context).cardColor;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _paperResults.length,
      itemBuilder: (context, index) {
        final result = _paperResults[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFD1E2D5)),
            boxShadow: isDarkMode ? [] : [
              BoxShadow(
                color: const Color(0xFF228B22).withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                      result.subject,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Сана: ${result.dateCreatedTajik}',
                      style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${result.score}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'балл',
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: textColor));
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: textColor,
          labelColor: textColor,
          unselectedLabelColor: textColor.withOpacity(0.4),
          tabs: const [
            Tab(text: 'Тестҳои фаъол'),
            Tab(text: 'Натиҷаҳо'),
            Tab(text: 'Тестҳои қоғазӣ'),
          ],
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              RefreshIndicator(
                onRefresh: _fetchTestData,
                color: textColor,
                child: _buildTestsList(textColor, isDarkMode),
              ),
              RefreshIndicator(
                onRefresh: _fetchTestData,
                color: textColor,
                child: _buildAttemptsList(textColor, isDarkMode),
              ),
              RefreshIndicator(
                onRefresh: _fetchTestData,
                color: textColor,
                child: _buildPaperResultsList(textColor, isDarkMode),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension on PaperTestResultModel {
  String get dateCreatedTajik {
    final year = dateCreated.year;
    final month = dateCreated.month.toString().padLeft(2, '0');
    final day = dateCreated.day.toString().padLeft(2, '0');
    final hour = dateCreated.hour.toString().padLeft(2, '0');
    final minute = dateCreated.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
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
