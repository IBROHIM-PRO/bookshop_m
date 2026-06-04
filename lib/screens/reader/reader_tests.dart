import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/test_model.dart';
import '../../services/api_service.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

    try {
      final testsResponse = await ApiService.get('/api/tests');
      final attemptsResponse = await ApiService.get('/api/tests/attempts');

      if (testsResponse.statusCode == 200 && attemptsResponse.statusCode == 200) {
        final List testsJson = jsonDecode(testsResponse.body);
        final List attemptsJson = jsonDecode(attemptsResponse.body);

        setState(() {
          _tests = testsJson.map((t) => TestModel.fromJson(t)).toList();
          _attempts = attemptsJson.map((a) => TestAttemptModel.fromJson(a)).toList();
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

  Widget _buildTestsList() {
    if (_tests.isEmpty) {
      return Center(
        child: Text(
          'Тестҳо айни замон дастрас нестанд',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tests.length,
      itemBuilder: (context, index) {
        final test = _tests[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                test.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (test.description != null && test.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  test.description!,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline, color: Colors.deepPurpleAccent, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '${test.questionCount} савол',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
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
                      backgroundColor: Colors.deepPurpleAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Сар кардан', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttemptsList() {
    if (_attempts.isEmpty) {
      return Center(
        child: Text(
          'Шумо то ҳол ягон тест насупоридаед',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _attempts.length,
      itemBuilder: (context, index) {
        final attempt = _attempts[index];
        final isPassed = attempt.percentage >= 50.0;
        final scoreColor = isPassed ? Colors.teal : Colors.redAccent;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Сана: ${attempt.dateCreatedTajik}',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
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
                      color: scoreColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${attempt.percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: scoreColor.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
    }

    return Column(
      children: [
        // TabBar headers
        TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepPurpleAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.4),
          tabs: const [
            Tab(text: 'Тестҳои фаъол'),
            Tab(text: 'Натиҷаҳо'),
          ],
        ),
        
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTestsList(),
              _buildAttemptsList(),
            ],
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
