import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/test_model.dart';
import '../../services/api_service.dart';

class TestQuizScreen extends StatefulWidget {
  final int testId;
  final String testTitle;

  const TestQuizScreen({super.key, required this.testId, required this.testTitle});

  @override
  State<TestQuizScreen> createState() => _TestQuizScreenState();
}

class _TestQuizScreenState extends State<TestQuizScreen> {
  TestModel? _test;
  bool _isLoading = true;
  int _currentQuestionIndex = 0;

  // Single: Map<questionId, 'A'/'B'/'C'/'D'>
  final Map<int, String> _singleAnswers = {};
  // Multiple: Map<questionId, Set<'A'/'B'/'C'/'D'>>
  final Map<int, Set<String>> _multipleAnswers = {};
  // Closed: Map<questionId, text>
  final Map<int, String> _closedAnswers = {};

  final Map<int, TextEditingController> _closedControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchTestDetails();
  }

  @override
  void dispose() {
    for (final c in _closedControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchTestDetails() async {
    try {
      final response = await ApiService.get('/api/tests/${widget.testId}');
      if (response.statusCode == 200) {
        final test = TestModel.fromJson(jsonDecode(response.body));
        // Pre-create controllers for closed questions
        for (final q in test.questions) {
          if (q.questionType == 'Closed') {
            _closedControllers[q.id] = TextEditingController();
          }
        }
        setState(() {
          _test = test;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _selectSingle(int questionId, String option) {
    setState(() {
      _singleAnswers[questionId] = option;
    });
  }

  void _toggleMultiple(int questionId, String option) {
    setState(() {
      _multipleAnswers[questionId] ??= {};
      if (_multipleAnswers[questionId]!.contains(option)) {
        _multipleAnswers[questionId]!.remove(option);
      } else {
        _multipleAnswers[questionId]!.add(option);
      }
    });
  }

  String _getAnswerForQuestion(QuestionModel q) {
    if (q.questionType == 'Single') {
      return _singleAnswers[q.id] ?? '';
    } else if (q.questionType == 'Multiple') {
      final selected = _multipleAnswers[q.id];
      if (selected == null || selected.isEmpty) return '';
      return selected.toList()..sort();
      // Return comma-separated sorted options
    } else {
      return _closedControllers[q.id]?.text.trim() ?? '';
    }
  }

  bool _isQuestionAnswered(QuestionModel q) {
    if (q.questionType == 'Single') {
      return _singleAnswers.containsKey(q.id);
    } else if (q.questionType == 'Multiple') {
      return (_multipleAnswers[q.id]?.isNotEmpty) ?? false;
    } else {
      return (_closedControllers[q.id]?.text.trim().isNotEmpty) ?? false;
    }
  }

  int get _answeredCount {
    if (_test == null) return 0;
    return _test!.questions.where(_isQuestionAnswered).length;
  }

  void _submitTest() async {
    if (_test == null) return;

    final answers = _test!.questions.map((q) {
      String answer = '';
      if (q.questionType == 'Single') {
        answer = _singleAnswers[q.id] ?? '';
      } else if (q.questionType == 'Multiple') {
        final sel = (_multipleAnswers[q.id] ?? {}).toList()..sort();
        answer = sel.join(',');
      } else {
        answer = _closedControllers[q.id]?.text.trim() ?? '';
      }
      return {'questionId': q.id, 'answer': answer};
    }).toList();

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post(
        '/api/tests/${widget.testId}/submit',
        {'answers': answers},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final int score = result['score'] ?? 0;
        final int earnedPoints = result['earnedPoints'] ?? 0;
        final int totalPoints = result['totalPoints'] ?? 0;
        final bool isGraded = result['isGraded'] ?? true;
        _showResultDialog(score, earnedPoints, totalPoints, isGraded);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Хатогӣ дар фиристодани тест'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хатогӣ дар пайвастшавӣ ба сервер'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showResultDialog(int score, int earnedPoints, int totalPoints, bool isGraded) {
    final double percentage = totalPoints > 0 ? (earnedPoints * 100) / totalPoints : 0;
    final isPassed = percentage >= 50.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E173E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Center(
          child: Icon(
            isGraded
                ? (isPassed ? Icons.check_circle : Icons.error)
                : Icons.pending_actions,
            color: isGraded
                ? (isPassed ? Colors.teal : Colors.redAccent)
                : Colors.amber,
            size: 64,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isGraded ? 'Натиҷаи Санҷиш' : 'Тест Қабул Шуд',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (isGraded) ...[
              Text(
                'Холҳои гирифташуда: $earnedPoints аз $totalPoints',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: isPassed ? Colors.teal : Colors.redAccent,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPassed
                    ? 'Офарин! Шумо санҷишро бомуваффақият супоридед.'
                    : 'Мутаассифона, холҳои шумо кам аст. Боз кӯшиш кунед.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Ҷавобҳои шумо қабул шуданд.\nОмӯзгор саволҳои навиштаниро тафтиш хоҳад кард ва натиҷа баъдтар ба шумо иттилоъ дода мешавад.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.6),
              ),
            ],
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Фаҳмо', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── Option Builders ───────────────────────────────────────────────────────

  Widget _buildSingleOption(String key, String text, bool isSelected, int questionId) {
    return GestureDetector(
      onTap: () => _selectSingle(questionId, key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurpleAccent.withOpacity(0.2)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.deepPurpleAccent : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepPurpleAccent : Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  key,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
            if (isSelected)
              const Icon(Icons.radio_button_checked, color: Colors.deepPurpleAccent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleOption(String key, String text, bool isSelected, int questionId) {
    return GestureDetector(
      onTap: () => _toggleMultiple(questionId, key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.indigo.withOpacity(0.2)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.indigo : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isSelected ? Colors.indigo : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(key, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedAnswer(QuestionModel q) {
    final controller = _closedControllers[q.id]!;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: controller,
        maxLines: 5,
        style: const TextStyle(color: Colors.white),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Ҷавоби худро ин ҷо нависед...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionOptions(QuestionModel question) {
    final options = [
      if (question.optionA.isNotEmpty) MapEntry('A', question.optionA),
      if (question.optionB.isNotEmpty) MapEntry('B', question.optionB),
      if (question.optionC.isNotEmpty) MapEntry('C', question.optionC),
      if (question.optionD.isNotEmpty) MapEntry('D', question.optionD),
    ];

    if (question.questionType == 'Closed') {
      return _buildClosedAnswer(question);
    } else if (question.questionType == 'Multiple') {
      final selected = _multipleAnswers[question.id] ?? {};
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Якчанд вариантро интихоб кунед',
              style: TextStyle(color: Colors.indigo.shade200, fontSize: 13),
            ),
          ),
          ...options.map((e) => _buildMultipleOption(e.key, e.value, selected.contains(e.key), question.id)),
        ],
      );
    } else {
      final selected = _singleAnswers[question.id];
      return Column(
        children: options.map((e) => _buildSingleOption(e.key, e.value, selected == e.key, question.id)).toList(),
      );
    }
  }

  String _questionTypeLabel(String type) {
    if (type == 'Multiple') return 'Якчанд вариант • ${_test!.questions[_currentQuestionIndex].points} хол';
    if (type == 'Closed') return 'Ҷавоби навиштанӣ • ${_test!.questions[_currentQuestionIndex].points} хол';
    return 'Як вариант • ${_test!.questions[_currentQuestionIndex].points} хол';
  }

  Color _questionTypeColor(String type) {
    if (type == 'Multiple') return Colors.indigo;
    if (type == 'Closed') return Colors.amber;
    return Colors.deepPurpleAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0C20),
        appBar: AppBar(
          backgroundColor: const Color(0xFF15102A),
          title: Text(widget.testTitle, style: const TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    if (_test == null || _test!.questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0C20),
        appBar: AppBar(
          backgroundColor: const Color(0xFF15102A),
          title: Text(widget.testTitle, style: const TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text('Саволҳо ёфт нашуданд.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final questions = _test!.questions;
    final currentQuestion = questions[_currentQuestionIndex];
    final isLastQuestion = _currentQuestionIndex == questions.length - 1;
    final progress = (_currentQuestionIndex + 1) / questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15102A),
        title: Text(widget.testTitle, style: const TextStyle(color: Colors.white, fontSize: 17)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '$_answeredCount/${questions.length}',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
            minHeight: 6,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Савол ${_currentQuestionIndex + 1} аз ${questions.length}',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _questionTypeColor(currentQuestion.questionType).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _questionTypeLabel(currentQuestion.questionType),
                    style: TextStyle(
                      color: _questionTypeColor(currentQuestion.questionType),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Text(
                      currentQuestion.questionText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildQuestionOptions(currentQuestion),
                ],
              ),
            ),
          ),

          // Bottom navigation
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF15102A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                if (_currentQuestionIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentQuestionIndex--),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Қаблӣ', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                if (_currentQuestionIndex > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isLastQuestion ? _submitTest : () => setState(() => _currentQuestionIndex++),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLastQuestion ? Colors.teal : Colors.deepPurpleAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      isLastQuestion ? '✓ Супоридани тест' : 'Навбатӣ →',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
