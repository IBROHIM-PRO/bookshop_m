import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

  // Timers and states
  Timer? _timer;
  int _secondsRemaining = 1200; // 20 minutes countdown

  // Single: Map<questionId, 'A'/'B'/'C'/'D'>
  final Map<int, String> _singleAnswers = {};
  // Multiple: Map<questionId, Set<'A'/'B'/'C'/'D'>>
  final Map<int, Set<String>> _multipleAnswers = {};
  // Closed: Map<questionId, fileUrl>
  final Map<int, String> _closedAnswers = {};

  // File uploading states per question
  final Map<int, bool> _uploadingStates = {};
  final Map<int, String> _uploadedFileNames = {};

  @override
  void initState() {
    super.initState();
    _fetchTestDetails();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        _timer?.cancel();
        _handleTimeOut();
      }
    });
  }

  void _handleTimeOut() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E173E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.timer_off_outlined, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text(
              'Вақт тамом шуд',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Вақти ҷудошуда барои супоридани санҷиш ба охир расид. Ҷавобҳои шумо ба таври худкор фиристода мешаванд.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _submitTest();
            },
            child: const Text('Фаҳмо', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }

  Future<void> _fetchTestDetails() async {
    try {
      final response = await ApiService.get('/api/tests/${widget.testId}');
      if (response.statusCode == 200) {
        final test = TestModel.fromJson(jsonDecode(response.body));
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

  bool _isQuestionAnswered(QuestionModel q) {
    if (q.questionType == 'Single' || q.questionType == 'TrueFalse') {
      return _singleAnswers.containsKey(q.id);
    } else if (q.questionType == 'Multiple') {
      return (_multipleAnswers[q.id]?.isNotEmpty) ?? false;
    } else {
      return (_closedAnswers[q.id]?.isNotEmpty) ?? false;
    }
  }

  void _submitTest() async {
    if (_test == null) return;

    if (_uploadingStates.values.any((uploading) => uploading)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Лутфан то анҷоми боргузории файлҳо интизор шавед'), backgroundColor: Colors.orange),
      );
      return;
    }

    final answers = _test!.questions.map((q) {
      String answer = '';
      if (q.questionType == 'Single' || q.questionType == 'TrueFalse') {
        answer = _singleAnswers[q.id] ?? '';
      } else if (q.questionType == 'Multiple') {
        final sel = (_multipleAnswers[q.id] ?? {}).toList()..sort();
        answer = sel.join(',');
      } else {
        answer = _closedAnswers[q.id] ?? '';
      }
      return {'questionId': q.id, 'answer': answer};
    }).toList();

    _timer?.cancel();
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
        final int optionEarnedPoints = result['optionEarnedPoints'] ?? earnedPoints;
        final int optionTotalPoints = result['optionTotalPoints'] ?? totalPoints;
        final bool isGraded = result['isGraded'] ?? true;
        _showResultDialog(score, earnedPoints, totalPoints, isGraded, optionEarnedPoints, optionTotalPoints);
      } else {
        setState(() => _isLoading = false);
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Хатогӣ дар фиристодани тест'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хатогӣ дар пайвастшавӣ ба сервер'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showResultDialog(int score, int earnedPoints, int totalPoints, bool isGraded, int optionEarnedPoints, int optionTotalPoints) {
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
                'Холҳои саволҳои вариантии санҷидашуда:\n$optionEarnedPoints аз $optionTotalPoints',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Ҷавобҳои шумо қабул шуданд.\nХолҳои саволҳои пӯшида (хаттӣ) дар охир аз тарафи муаллим гузошта мешаванд.',
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

  Future<void> _pickAndUploadFile(int questionId) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final name = result.files.single.name;

      setState(() {
        _uploadingStates[questionId] = true;
      });

      final response = await ApiService.uploadFile(path, name);

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final fileUrl = resData['url'] as String?;
        if (fileUrl != null) {
          setState(() {
            _closedAnswers[questionId] = fileUrl;
            _uploadedFileNames[questionId] = name;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Хатогӣ дар боргузории файл'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Хатогӣ: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() {
        _uploadingStates[questionId] = false;
      });
    }
  }

  Widget _buildOptionCard({
    required String key,
    required String text,
    required bool isSelected,
    required bool isMultiple,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEDE7F6) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey[200]!,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Option circle/checkbox
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepPurple : Colors.transparent,
                shape: isMultiple ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isMultiple ? BorderRadius.circular(6) : null,
                border: Border.all(
                  color: isSelected ? Colors.deepPurple : Colors.grey[400]!,
                  width: 1.8,
                ),
              ),
              child: Center(
                child: isSelected
                    ? Icon(
                        isMultiple ? Icons.check : Icons.circle,
                        color: Colors.white,
                        size: isMultiple ? 16 : 10,
                      )
                    : Text(
                        key,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: const Color(0xFF1E1C24),
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedAnswer(QuestionModel q) {
    final isUploading = _uploadingStates[q.id] ?? false;
    final fileName = _uploadedFileNames[q.id];
    final fileUrl = _closedAnswers[q.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fileUrl == null || fileUrl.isEmpty) ...[
          if (isUploading) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!, width: 1.5),
              ),
              child: const Column(
                children: [
                  CircularProgressIndicator(color: Colors.deepPurple),
                  SizedBox(height: 12),
                  Text(
                    'Файл боргузорӣ шуда истодааст...',
                    style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: () => _pickAndUploadFile(q.id),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.deepPurple.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, color: Colors.deepPurple[400], size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Илова кардани файл',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Шумо метавонед расм ё ҳуҷҷатро аз телефони худ боргузорӣ кунед',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA5D6A7), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName ?? 'Файли боргузоришуда',
                        style: const TextStyle(
                          color: Color(0xFF1E4620),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Муваффақият бор карда шуд',
                        style: TextStyle(color: Colors.black45, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () {
                    setState(() {
                      _closedAnswers.remove(q.id);
                      _uploadedFileNames.remove(q.id);
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ],
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
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          ...options.map((e) => _buildOptionCard(
                key: e.key,
                text: e.value,
                isSelected: selected.contains(e.key),
                isMultiple: true,
                onTap: () => _toggleMultiple(question.id, e.key),
              )),
        ],
      );
    } else {
      final selected = _singleAnswers[question.id];
      return Column(
        children: options.map((e) => _buildOptionCard(
              key: e.key,
              text: e.value,
              isSelected: selected == e.key,
              isMultiple: false,
              onTap: () => _selectSingle(question.id, e.key),
            )).toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF4A148C),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_test == null || _test!.questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF4A148C),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF311B92),
              Color(0xFF512DA8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top custom header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    Text(
                      '${(_currentQuestionIndex + 1).toString().padLeft(2, '0')} аз ${questions.length.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _formatTime(_secondsRemaining),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (questions.isNotEmpty) ? (_currentQuestionIndex + 1) / questions.length : 0,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C853)),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // White Question Card
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.testTitle.toUpperCase(),
                          style: TextStyle(
                            color: Colors.deepPurple[300],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentQuestion.questionText,
                          style: const TextStyle(
                            color: Color(0xFF1E1C24),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                        if (currentQuestion.imageUrl != null && currentQuestion.imageUrl!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              currentQuestion.imageUrl!.startsWith('http')
                                  ? currentQuestion.imageUrl!
                                  : '${ApiService.baseUrl}${currentQuestion.imageUrl}',
                              fit: BoxFit.contain,
                              height: 180,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Хатогӣ дар боргузории сурат',
                                      style: TextStyle(color: Colors.black38),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey[200], thickness: 1.5),
                        const SizedBox(height: 20),
                        _buildQuestionOptions(currentQuestion),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom control buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    if (_currentQuestionIndex > 0) ...[
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () => setState(() => _currentQuestionIndex--),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'БА АҚИБ',
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isLastQuestion ? _submitTest : () => setState(() => _currentQuestionIndex++),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 4,
                        ),
                        child: Text(
                          isLastQuestion ? 'СУПОРИДАН' : 'НАВБАТӢ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
