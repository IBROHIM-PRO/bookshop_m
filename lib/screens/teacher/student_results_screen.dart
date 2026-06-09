import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class StudentResultsScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String studentEmail;

  const StudentResultsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
  });

  @override
  State<StudentResultsScreen> createState() => _StudentResultsScreenState();
}

class _StudentResultsScreenState extends State<StudentResultsScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await ApiService.get('/api/teacher/student/${widget.studentId}/statistics');
      if (response.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(response.body);
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

  void _showAttemptDetails(int attemptId) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF162218),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return FutureBuilder(
              future: ApiService.get('/api/tests/attempts/$attemptId'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1E7431)));
                }
                if (snapshot.hasError || snapshot.data?.statusCode != 200) {
                  return const Center(child: Text('Хатогӣ дар боркунии маълумот', style: TextStyle(color: Colors.white)));
                }

                final detail = jsonDecode(snapshot.data!.body);
                final answers = detail['answers'] as List;

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      detail['testTitle'] ?? 'Тафсилоти кӯшиши супоридан',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Нишондиҳанда: ${detail['earnedPoints']} / ${detail['totalPoints']} балл',
                      style: const TextStyle(color: Color(0xFFA3E635), fontWeight: FontWeight.bold),
                    ),
                    const Divider(color: Color(0xFF2E3D32), height: 32),

                    ...answers.map((ans) {
                      final bool isClosed = ans['questionType'] == 'Closed';
                      final int earned = ans['earnedPoints'] ?? 0;
                      final int maxPoints = ans['maxPoints'] ?? 10;
                      final isCorrect = earned > 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF162218),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2E3D32)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  ans['questionType'] == 'TrueFalse'
                                      ? 'Рост/Дурӯғ'
                                      : (isClosed ? 'Саволи хаттӣ' : 'Саволи интихобӣ'),
                                  style: TextStyle(color: isClosed ? Colors.amber : const Color(0xFFA3E635), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isClosed 
                                        ? Colors.amber.withOpacity(0.1) 
                                        : (isCorrect ? Colors.teal.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$earned / $maxPoints хол',
                                    style: TextStyle(
                                      color: isClosed 
                                          ? Colors.amber 
                                          : (isCorrect ? Colors.teal : Colors.redAccent),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              ans['questionText'] ?? '',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ҷавоби хонанда:',
                                    style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ans['studentAnswer'] ?? 'Ҷавоб дода нашудааст',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            if (!isClosed) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Ҷавоби дурусти система: ${ans['correctOption']}',
                                style: const TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D120E),
        appBar: AppBar(
          title: Text(widget.studentName),
          backgroundColor: const Color(0xFF162218),
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF1E7431))),
      );
    }

    final attempts = _stats?['testAttempts'] as List? ?? [];
    final average = _stats?['averageScorePercentage'] ?? 0;
    final booksCount = _stats?['booksReadCount'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D120E),
      appBar: AppBar(
        title: Text(widget.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF162218),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF162218),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2E3D32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      child: const Icon(Icons.person, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.studentName,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.studentEmail,
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Stats overview row
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        'Китобҳо',
                        '$booksCount',
                        Icons.menu_book,
                        Colors.tealAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryItem(
                        'Тестҳо',
                        '${attempts.length}',
                        Icons.quiz,
                        Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryItem(
                        'Баҳои миёна',
                        '$average%',
                        Icons.grade,
                        Colors.pinkAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Натиҷаҳои санҷишҳо (Тестҳо)',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (attempts.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.quiz_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    Text(
                      'То ҳол ягон тест насупоридааст',
                      style: TextStyle(color: Colors.white.withOpacity(0.4)),
                    ),
                  ],
                ),
              ),
            )
          else
            ...attempts.map((a) {
              final double percent = (a['percentage'] as num).toDouble();
              final isPassed = percent >= 50.0;
              final isGraded = a['isGraded'] ?? true;
              final int attemptId = a['id'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF162218),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2E3D32)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  onTap: () => _showAttemptDetails(attemptId),
                  title: Text(
                    a['testTitle'] ?? '',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (isGraded)
                        Text(
                          'Холҳо: ${a['earnedPoints']} аз ${a['totalPoints']}',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        )
                      else
                        Text(
                          'Холҳои вариантӣ: ${a['optionEarnedPoints'] ?? a['earnedPoints']} аз ${a['optionTotalPoints'] ?? a['totalPoints']}',
                          style: TextStyle(color: const Color(0xFFA3E635), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      if (!isGraded)
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Баҳогузорӣ лозим',
                            style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isGraded 
                          ? (isPassed ? Colors.teal.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1))
                          : Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isGraded ? '${percent.toStringAsFixed(0)}%' : 'Тафтиш',
                      style: TextStyle(
                        color: isGraded 
                            ? (isPassed ? const Color(0xFFA3E635) : Colors.redAccent)
                            : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
