import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';

class _TutorMessage {
  final String text;
  final bool isUser;
  final Map<String, dynamic>? fullData;

  _TutorMessage({required this.text, required this.isUser, this.fullData});
}

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_TutorMessage> _messages = [];
  bool _isLoading = false;
  late AnimationController _pulseController;
  Map<String, dynamic>? _lastAiData;

  // Settings
  int _weeksToExam = 8;
  int _dailyHours = 3;
  String _targetSpecialty = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _messages.add(_TutorMessage(
      text: 'Салом! Ман мураббии шахсии шумо ҳастам 🎓\n\n'
          'Ман натиҷаҳои тестҳои шуморо таҳлил карда:\n'
          '• Нуқтаҳои заифро ошкор мекунам\n'
          '• Нақшаи омӯзиши шахсӣ месозам\n'
          '• Пешрафти шуморо пайгирӣ мекунам\n\n'
          'Барои оғоз саволатонро нависед!',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendRequest({String? customPrompt}) async {
    final query = customPrompt ?? _inputController.text.trim();
    if (query.isEmpty && customPrompt == null) return;

    if (customPrompt == null) _inputController.clear();

    setState(() {
      _messages.add(_TutorMessage(text: query, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await ApiService.postWithTimeout('/api/Ntc/ai-tutor', {
        'prompt': query,
        'targetSpecialty': _targetSpecialty,
        'weeksToExam': _weeksToExam,
        'dailyHours': _dailyHours,
      }, const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _lastAiData = data;
          _messages.add(_TutorMessage(
            text: data['responseText'] ?? '',
            isUser: false,
            fullData: data,
          ));
          _isLoading = false;
        });
      } else {
        setState(() {
          _messages.add(_TutorMessage(text: 'Хатогӣ рух дод. Лутфан такрор кунед.', isUser: false));
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(_TutorMessage(text: 'Алоқа бо сервер дастнорас аст.', isUser: false));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bg = isDark ? const Color(0xFF0A0F0D) : const Color(0xFFF5FAF7);
    final cardBg = isDark ? const Color(0xFF141C17) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2E22);
    final accent = const Color(0xFF22873B);
    final subtle = textColor.withOpacity(0.5);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0D120E) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accent, accent.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Мураббии AI', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Онлайн', style: TextStyle(color: accent, fontSize: 11)),
                ],
              ),
            ],
          ),
          actions: const [],
          bottom: TabBar(
            indicatorColor: accent,
            labelColor: accent,
            unselectedLabelColor: subtle,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Чатбот'),
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Таҳлил'),
              Tab(icon: Icon(Icons.explore_outlined), text: 'Ихтисосҳо'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Chatbot
            Column(
              children: [
                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) {
                        return _buildTypingIndicator(isDark, subtle);
                      }
                      final msg = _messages[i];
                      if (msg.isUser) return _buildUserBubble(msg, textColor, isDark);
                      return _buildAiBubble(msg, textColor, isDark, cardBg, accent, subtle);
                    },
                  ),
                ),

                // Input bar
                Container(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D120E) : Colors.white,
                    border: Border(top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFD6E8DC))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F8F4),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _inputController,
                            style: TextStyle(color: textColor, fontSize: 14),
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: 'Саволатонро нависед...',
                              hintStyle: TextStyle(color: subtle, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                            onSubmitted: (_) => _sendRequest(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isLoading ? null : () => _sendRequest(),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [accent, accent.withOpacity(0.8)]),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Tab 2: Analytics Panel
            _buildDashboardTab(isDark, textColor, cardBg, accent, subtle),

            // Tab 3: Recommended Specialties
            _buildRecommendationsTab(isDark, textColor, cardBg, accent, subtle),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark, Color subtle) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: const BorderRadius.only(topRight: Radius.circular(18), bottomRight: Radius.circular(18), topLeft: Radius.circular(18)),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFD6E8DC)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Row(
                children: List.generate(3, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22873B).withOpacity(0.3 + _pulseController.value * 0.5 * ((i + 1) / 3)),
                    shape: BoxShape.circle,
                  ),
                )),
              ),
            ),
            const SizedBox(width: 8),
            Text('Таҳлил мекунам...', style: TextStyle(color: subtle, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(_TutorMessage msg, Color textColor, bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 12, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF22873B), Color(0xFF1A6E30)]),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), bottomLeft: Radius.circular(18), topRight: Radius.circular(18)),
        ),
        child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }

  Widget _buildAiBubble(_TutorMessage msg, Color textColor, bool isDark, Color cardBg, Color accent, Color subtle) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        margin: const EdgeInsets.only(bottom: 16, right: 30),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.only(topRight: Radius.circular(18), bottomRight: Radius.circular(18), topLeft: Radius.circular(18)),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFD6E8DC)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Text(msg.text, style: TextStyle(color: textColor, fontSize: 13.5, height: 1.5)),
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard(List recommendations, Color textColor, bool isDark, Color cardBg, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFD6E8DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.explore_outlined, color: accent, size: 18),
              const SizedBox(width: 6),
              Text('Ихтисосҳои тавсияшуда', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ...recommendations.take(4).map((rec) {
            final spec = rec['specialty'];
            final matchType = rec['matchType'];
            final feedback = rec['feedback'];
            final acceptanceChance = rec['acceptanceChance'];

            Color badgeColor;
            String badgeText;
            if (matchType == 'Safe') {
              badgeColor = Colors.green;
              badgeText = 'Шонси баланд';
            } else if (matchType == 'Target') {
              badgeColor = Colors.orange;
              badgeText = 'Бо кӯшиш';
            } else {
              badgeColor = Colors.red;
              badgeText = 'Кӯшиши зиёд';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF9FBF9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: badgeColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '${acceptanceChance.toString()}%',
                        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${spec['specialtyCode']} - ${spec['specialtyName']}',
                    style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spec['universityName'] ?? '',
                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildMiniInfoChip(
                        Icons.payments_outlined,
                        spec['tuitionFee'] != null && spec['tuitionFee'] > 0 ? '${spec['tuitionFee']} сомонӣ' : 'Ройгон',
                        spec['tuitionFee'] != null && spec['tuitionFee'] > 0 ? Colors.amber.shade800 : Colors.green,
                        isDark,
                      ),
                      const SizedBox(width: 6),
                      _buildMiniInfoChip(
                        Icons.emoji_events_outlined,
                        spec['lastYearPassingScore'] != null && spec['lastYearPassingScore'] > 0
                            ? '${spec['lastYearPassingScore']} бал'
                            : 'озод',
                        Colors.blue,
                        isDark,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMiniInfoChip(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisCard(List diagnosis, Color textColor, bool isDark, Color cardBg, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFD6E8DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: accent, size: 18),
              const SizedBox(width: 6),
              Text('Ташхиси фанҳо (BKT)', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ...diagnosis.map((d) {
            final mastery = (d['masteryPercent'] as num?)?.toDouble() ?? 0;
            final level = d['level'] as String? ?? '';
            final subject = d['subject'] as String? ?? '';
            final color = mastery >= 80 ? Colors.green : mastery >= 60 ? Colors.orange : Colors.redAccent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(subject, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text('$level ${mastery.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: mastery / 100,
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStreakBadge(int streak, bool isDark, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.orange.shade800, Colors.deepOrange]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text('$streak рӯзи пайдарпай!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTrajectoryCard(List trajectory, Color textColor, bool isDark, Color cardBg, Color accent) {
    if (trajectory.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFD6E8DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.blue.shade600, size: 18),
              const SizedBox(width: 6),
              Text('Траекторияи пешрафт', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: const Size(double.infinity, 120),
              painter: _TrajectoryPainter(
                trajectory: trajectory,
                isDark: isDark,
                accentColor: accent,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(width: 10, height: 3, color: accent),
              const SizedBox(width: 4),
              Text('Пешбинӣ', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10)),
              const SizedBox(width: 12),
              Container(width: 10, height: 3, color: Colors.redAccent.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text('Ҳадаф', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPlanCard(List plan, Color textColor, bool isDark, Color cardBg, Color accent) {
    final subjectColors = {
      'Химия': Colors.purple, 'Биология': Colors.green, 'Физика': Colors.blue, 'Забони тоҷикӣ': Colors.orange,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFD6E8DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.teal, size: 18),
              const SizedBox(width: 6),
              Text('Ҷадвали ҳафтагӣ', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          ...plan.map((day) {
            final primary = day['primarySubject'] as String? ?? '';
            final secondary = day['secondarySubject'] as String? ?? '';
            final hours = day['hours'] as int? ?? 3;
            final dayName = day['day'] as String? ?? '';
            final pColor = subjectColors[primary] ?? accent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(width: 80, child: Text(dayName, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: pColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text(primary, style: TextStyle(color: pColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  Text('+', style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 10)),
                  const SizedBox(width: 4),
                  Text(secondary, style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 10)),
                  const Spacer(),
                  Text('${hours}с', style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }



  Widget _buildDashboardTab(bool isDark, Color textColor, Color cardBg, Color accent, Color subtle) {
    if (_lastAiData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 64, color: subtle),
              const SizedBox(height: 16),
              Text(
                'Панели таҳлилӣ холӣ аст',
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Барои дидани панели таҳлилӣ, аввал дар чатбот савол диҳед ва сатҳатонро ташхис кунед.',
                style: TextStyle(color: subtle, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final data = _lastAiData!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Streak badge
        if (data['streak'] != null && (data['streak'] as int) > 0)
          Center(child: _buildStreakBadge(data['streak'] as int, isDark, accent)),
        if (data['streak'] != null && (data['streak'] as int) > 0)
          const SizedBox(height: 12),

        // Diagnosis cards
        if (data['diagnosis'] != null) ...[
          _buildDiagnosisCard(data['diagnosis'] as List, textColor, isDark, cardBg, accent),
          const SizedBox(height: 12),
        ],

        // Trajectory mini-chart
        if (data['trajectory'] != null) ...[
          _buildTrajectoryCard(data['trajectory'] as List, textColor, isDark, cardBg, accent),
          const SizedBox(height: 12),
        ],

        // Weekly plan
        if (data['weeklyPlan'] != null) ...[
          _buildWeeklyPlanCard(data['weeklyPlan'] as List, textColor, isDark, cardBg, accent),
        ],
      ],
    );
  }

  Widget _buildRecommendationsTab(bool isDark, Color textColor, Color cardBg, Color accent, Color subtle) {
    if (_lastAiData == null || _lastAiData!['recommendations'] == null || (_lastAiData!['recommendations'] as List).isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore_outlined, size: 64, color: subtle),
              const SizedBox(height: 16),
              Text(
                'Ихтисосҳо ёфт нашуданд',
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Барои дидани ихтисосҳои тавсияшуда, дар чатбот савол диҳед (масалан: "Ихтисосҳоро тавсия кун").',
                style: TextStyle(color: subtle, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final recommendations = _lastAiData!['recommendations'] as List;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.explore_outlined, color: accent, size: 18),
            const SizedBox(width: 6),
            Text(
              'Ихтисосҳои тавсияшуда (Шонси қабул)',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...recommendations.map((rec) {
          final spec = rec['specialty'];
          final matchType = rec['matchType'];
          final feedback = rec['feedback'];
          final acceptanceChance = rec['acceptanceChance'];

          Color badgeColor;
          String badgeText;
          if (matchType == 'Safe') {
            badgeColor = Colors.green;
            badgeText = 'Шонси баланд';
          } else if (matchType == 'Target') {
            badgeColor = Colors.orange;
            badgeText = 'Бо кӯшиш';
          } else {
            badgeColor = Colors.red;
            badgeText = 'Кӯшиши зиёд';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFD6E8DC)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${acceptanceChance.toString()}%',
                      style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${spec['specialtyCode']} - ${spec['specialtyName']}',
                  style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  spec['universityName'] ?? '',
                  style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMiniInfoChip(
                      Icons.payments_outlined,
                      spec['tuitionFee'] != null && spec['tuitionFee'] > 0 ? '${spec['tuitionFee']} сомонӣ' : 'Ройгон',
                      spec['tuitionFee'] != null && spec['tuitionFee'] > 0 ? Colors.amber.shade800 : Colors.green,
                      isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildMiniInfoChip(
                      Icons.emoji_events_outlined,
                      spec['lastYearPassingScore'] != null && spec['lastYearPassingScore'] > 0
                          ? '${spec['lastYearPassingScore']} бал'
                          : 'озод',
                      Colors.blue,
                      isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF9FBF9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    feedback ?? '',
                    style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TrajectoryPainter extends CustomPainter {
  final List trajectory;
  final bool isDark;
  final Color accentColor;

  _TrajectoryPainter({required this.trajectory, required this.isDark, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (trajectory.isEmpty) return;

    double minScore = double.infinity, maxScore = 0;
    for (var p in trajectory) {
      final proj = (p['projectedScore'] as num?)?.toDouble() ?? 0;
      final targ = (p['targetScore'] as num?)?.toDouble() ?? 0;
      minScore = min(minScore, min(proj, targ));
      maxScore = max(maxScore, max(proj, targ));
    }
    minScore = (minScore - 20).clamp(0, 400);
    maxScore = maxScore + 20;
    double range = maxScore - minScore;
    if (range < 10) range = 10;

    final projPaint = Paint()..color = accentColor..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final targPaint = Paint()..color = Colors.redAccent.withOpacity(0.5)..strokeWidth = 1.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = accentColor;
    final gridPaint = Paint()..color = (isDark ? Colors.white12 : Colors.grey.shade200)..strokeWidth = 0.5;

    int totalWeeks = trajectory.length - 1;
    if (totalWeeks < 1) totalWeeks = 1;

    // Grid lines
    for (int i = 0; i <= 4; i++) {
      double y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Projected line
    final projPath = Path();
    final targPath = Path();
    for (int i = 0; i < trajectory.length; i++) {
      double x = (i / totalWeeks) * size.width;
      double projY = size.height - ((((trajectory[i]['projectedScore'] as num?)?.toDouble() ?? 0) - minScore) / range) * size.height;
      double targY = size.height - ((((trajectory[i]['targetScore'] as num?)?.toDouble() ?? 0) - minScore) / range) * size.height;

      if (i == 0) {
        projPath.moveTo(x, projY);
        targPath.moveTo(x, targY);
      } else {
        projPath.lineTo(x, projY);
        targPath.lineTo(x, targY);
      }
      canvas.drawCircle(Offset(x, projY), 3, dotPaint);
    }
    canvas.drawPath(projPath, projPaint);
    canvas.drawPath(targPath, targPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
