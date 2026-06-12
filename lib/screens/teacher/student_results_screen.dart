import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StudentResultsScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String studentEmail;
  final String? studentImageUrl;

  const StudentResultsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    this.studentImageUrl,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final cardBg = isDarkMode ? const Color(0xFF162218) : const Color(0xFFF3F4F6);
    final borderColor = isDarkMode ? const Color(0xFF2E3D32) : const Color(0xFFE5E7EB);
    final innerBg = isDarkMode ? Colors.black12 : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF162218) : Colors.white,
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
                  return Center(child: Text('Хатогӣ дар боркунии маълумот', style: TextStyle(color: textColor)));
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
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white24 : Colors.black26, 
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      detail['testTitle'] ?? 'Тафсилоти кӯшиши супоридан',
                      style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Нишондиҳанда: ${detail['earnedPoints']} / ${detail['totalPoints']} балл',
                      style: const TextStyle(color: Color(0xFF1E7431), fontWeight: FontWeight.bold),
                    ),
                    Divider(color: borderColor, height: 32),

                    ...answers.map((ans) {
                      final bool isClosed = ans['questionType'] == 'Closed';
                      final int earned = ans['earnedPoints'] ?? 0;
                      final int maxPoints = ans['maxPoints'] ?? 10;
                      final isCorrect = earned > 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
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
                                  style: TextStyle(color: isClosed ? Colors.amber : const Color(0xFF1E7431), fontSize: 11, fontWeight: FontWeight.bold),
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
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: innerBg,
                                borderRadius: BorderRadius.circular(10),
                                border: isDarkMode ? null : Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ҷавоби хонанда:',
                                    style: TextStyle(color: isDarkMode ? Colors.white30 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ans['studentAnswer'] ?? 'Ҷавоб дода нашудааст',
                                    style: TextStyle(color: textColor, fontSize: 13),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDarkMode ? const Color(0xFF0D120E) : const Color(0xFFF1F8F4);
    final cardBg = isDarkMode ? const Color(0xFF162218) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final borderColor = isDarkMode ? const Color(0xFF2E3D32) : const Color(0xFFE5E7EB);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: Text(
            widget.studentName,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF1E7431))),
      );
    }

    final attempts = _stats?['testAttempts'] as List? ?? [];
    final average = _stats?['averageScorePercentage'] ?? 0;
    final booksCount = _stats?['booksReadCount'] ?? 0;
    final paperResults = _stats?['paperTestResults'] as List? ?? [];

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          widget.studentName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                      backgroundImage: widget.studentImageUrl != null && widget.studentImageUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(ApiService.getFullImageUrl(widget.studentImageUrl))
                          : null,
                      child: widget.studentImageUrl != null && widget.studentImageUrl!.isNotEmpty
                          ? null
                          : Text(
                              _getInitials(widget.studentName),
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.studentName,
                            style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.studentEmail,
                            style: TextStyle(color: subTextColor, fontSize: 13),
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
                        Colors.teal,
                        isDarkMode,
                        textColor,
                        subTextColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryItem(
                        'Тестҳо',
                        '${attempts.length}',
                        Icons.quiz,
                        Colors.orange,
                        isDarkMode,
                        textColor,
                        subTextColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryItem(
                        'Баҳои миёна',
                        '$average%',
                        Icons.grade,
                        Colors.pink,
                        isDarkMode,
                        textColor,
                        subTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Натиҷаҳои санҷишҳо (Тестҳо)',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (attempts.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.quiz_outlined, size: 48, color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.15)),
                    const SizedBox(height: 12),
                    Text(
                      'То ҳол ягон тест насупоридааст',
                      style: TextStyle(color: subTextColor),
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
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  onTap: () => _showAttemptDetails(attemptId),
                  title: Text(
                    a['testTitle'] ?? '',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (isGraded)
                        Text(
                          'Холҳо: ${a['earnedPoints']} аз ${a['totalPoints']}',
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        )
                      else
                        Text(
                          'Холҳои вариантӣ: ${a['optionEarnedPoints'] ?? a['earnedPoints']} аз ${a['optionTotalPoints'] ?? a['totalPoints']}',
                          style: const TextStyle(color: Color(0xFF1E7431), fontSize: 12, fontWeight: FontWeight.bold),
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
                            ? (isPassed ? const Color(0xFF1E7431) : Colors.redAccent)
                            : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
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
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.menu_book_outlined, size: 48, color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.15)),
                    const SizedBox(height: 12),
                    Text(
                      'Натиҷаи тестҳои қоғазӣ мавҷуд нест',
                      style: TextStyle(color: subTextColor),
                    ),
                  ],
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
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    subject,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Сана: $dateStr',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$score балл',
                      style: const TextStyle(
                        color: Color(0xFF1E7431),
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

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color, bool isDarkMode, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: subTextColor, fontSize: 10),
          ),
        ],
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
