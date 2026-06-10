import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/test_model.dart';
import '../../services/api_service.dart';
import '../../providers/theme_provider.dart';

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
  Map<String, dynamic>? _submissionResult;
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
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: textColor.withOpacity(0.1)),
        ),
        title: Row(
          children: [
            Icon(Icons.timer_off_outlined, color: textColor, size: 28),
            const SizedBox(width: 10),
            Text(
              'Вақт тамом шуд',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Вақти ҷудошуда барои супоридани санҷиш ба охир расид. Ҷавобҳои шумо ба таври худкор фиристода мешаванд.',
          style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _submitTest();
            },
            child: Text('Фаҳмо', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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
        setState(() {
          _submissionResult = result;
          _isLoading = false;
        });
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

  Widget _buildSuccessScreen(ThemeData theme, Color textColor, Color backgroundColor, bool isDarkMode) {
    final result = _submissionResult!;
    final int score = result['score'] ?? 0;
    final int earnedPoints = result['earnedPoints'] ?? 0;
    final int totalPoints = result['totalPoints'] ?? 0;
    final int optionEarnedPoints = result['optionEarnedPoints'] ?? earnedPoints;
    final int optionTotalPoints = result['optionTotalPoints'] ?? totalPoints;
    final bool isGraded = result['isGraded'] ?? true;
    final double percentage = totalPoints > 0 ? (earnedPoints * 100) / totalPoints : 0;
    final isPassed = percentage >= 50.0;

    String titleText = isGraded 
        ? (isPassed ? 'Санҷиш супорида шуд' : 'Санҷиш ноком шуд')
        : 'Ҷавобҳо қабул шуданд';
        
    String description = '';
    if (isGraded) {
      description = 'Холҳои гирифташуда: $earnedPoints аз $totalPoints (${percentage.toStringAsFixed(1)}%)\n\n' +
          (isPassed 
              ? 'Офарин! Шумо санҷишро бомуваффақият супоридед.'
              : 'Мутаассифона, холҳои шумо барои гузаштан кам аст. Боз кӯшиш кунед.');
    } else {
      description = 'Холҳои саволҳои вариантӣ: $optionEarnedPoints аз $optionTotalPoints\n\n'
          'Ҷавобҳои шумо бомуваффақият қабул шуданд. Муаллим холҳои саволҳои пӯшида (хаттӣ)-ро дертар месанҷад.';
    }

    final accentColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Оформлено',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            children: [
              const Spacer(),
              // Light lavender circle with purple checkmark (matching image 3)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isDarkMode ? accentColor.withOpacity(0.15) : const Color(0xFFEEECFC),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isGraded && !isPassed ? Icons.close_rounded : Icons.check_rounded,
                    color: isGraded && !isPassed ? Colors.redAccent : accentColor,
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // Success bold title
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              // Description body text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              // Return home button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Ба саҳифаи асосӣ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadFile(int questionId) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
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
    required Color textColor,
    required Color backgroundColor,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final cardBgColor = isDarkMode
        ? (isSelected ? theme.colorScheme.primary.withOpacity(0.15) : theme.cardColor)
        : (isSelected ? const Color(0xFFEBF3ED) : Colors.white);

    final borderColor = isDarkMode
        ? (isSelected ? theme.colorScheme.primary : textColor.withOpacity(0.1))
        : (isSelected ? const Color(0xFF1E7431) : const Color(0xFFD1E2D5));

    final optionTextColor = isDarkMode
        ? textColor
        : (isSelected ? const Color(0xFF1E7431) : const Color(0xFF1A1F1C));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: isDarkMode ? [] : [
            BoxShadow(
              color: const Color(0xFF228B22).withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
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
                color: isSelected
                    ? (isDarkMode ? theme.colorScheme.primary : const Color(0xFF1E7431))
                    : Colors.transparent,
                shape: isMultiple ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isMultiple ? BorderRadius.circular(6) : null,
                border: Border.all(
                  color: isSelected
                      ? (isDarkMode ? theme.colorScheme.primary : const Color(0xFF1E7431))
                      : (isDarkMode ? textColor.withOpacity(0.4) : const Color(0xFF8A9A8E)),
                  width: 1.8,
                ),
              ),
              child: Center(
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : Text(
                        key,
                        style: TextStyle(
                          color: isDarkMode ? textColor.withOpacity(0.8) : const Color(0xFF657367),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: optionTextColor,
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

  Widget _buildClosedAnswer(QuestionModel q, Color textColor, Color backgroundColor) {
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
                color: textColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: textColor.withOpacity(0.1), width: 1.5),
              ),
              child: Column(
                children: [
                  CircularProgressIndicator(color: textColor),
                  const SizedBox(height: 12),
                  Text(
                    'Файл боргузорӣ шуда истодааст...',
                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w500),
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
                  color: textColor.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: textColor.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, color: textColor.withOpacity(0.5), size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Илова кардани файл',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Шумо метавонед расм ё ҳуҷҷатро аз телефони худ боргузорӣ кунед',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor.withOpacity(0.5),
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
              color: textColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: textColor.withOpacity(0.2), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.insert_drive_file_outlined, color: textColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName ?? 'Файли боргузоришуда',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Муваффақият бор карда шуд',
                        style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12),
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

  Widget _buildQuestionOptions(QuestionModel question, Color textColor, Color backgroundColor) {
    final options = [
      if (question.optionA.isNotEmpty) MapEntry('A', question.optionA),
      if (question.optionB.isNotEmpty) MapEntry('B', question.optionB),
      if (question.optionC.isNotEmpty) MapEntry('C', question.optionC),
      if (question.optionD.isNotEmpty) MapEntry('D', question.optionD),
    ];

    if (question.questionType == 'Closed') {
      return _buildClosedAnswer(question, textColor, backgroundColor);
    } else if (question.questionType == 'Multiple') {
      final selected = _multipleAnswers[question.id] ?? {};
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Якчанд вариантро интихоб кунед',
              style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13),
            ),
          ),
          ...options.map((e) => _buildOptionCard(
                key: e.key,
                text: e.value,
                isSelected: selected.contains(e.key),
                isMultiple: true,
                onTap: () => _toggleMultiple(question.id, e.key),
                textColor: textColor,
                backgroundColor: backgroundColor,
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
              textColor: textColor,
              backgroundColor: backgroundColor,
            )).toList(),
      );
    }
  }

  Future<bool> _showExitWarningDialog() async {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: textColor.withOpacity(0.1)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
            const SizedBox(width: 10),
            Text(
              'Огоҳӣ',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Шумо дар вақти супоридани тест ҳастед. Агар ҳозир бароед, натиҷаҳои шумо сабт намешаванд. Оё дар ҳақиқат мехоҳед тестро тарк кунед?',
          style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Бекор кардан', style: TextStyle(color: textColor.withOpacity(0.6), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Баромадан', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    if (_submissionResult != null) {
      return _buildSuccessScreen(theme, textColor, backgroundColor, isDarkMode);
    }

    if (_test == null || _test!.questions.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(widget.testTitle, style: TextStyle(color: textColor)),
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Center(
          child: Text('Саволҳо ёфт нашуданд.', style: TextStyle(color: textColor)),
        ),
      );
    }

    final questions = _test!.questions;
    final currentQuestion = questions[_currentQuestionIndex];
    final isLastQuestion = _currentQuestionIndex == questions.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitWarningDialog();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
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
                        color: textColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: textColor.withOpacity(0.1)),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
                        onPressed: () async {
                          final shouldPop = await _showExitWarningDialog();
                          if (shouldPop && mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                  Text(
                    '${(_currentQuestionIndex + 1).toString().padLeft(2, '0')} аз ${questions.length.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: textColor.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, color: textColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(_secondsRemaining),
                          style: TextStyle(
                            color: textColor,
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
                  backgroundColor: textColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Question Card
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: textColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.testTitle.toUpperCase(),
                        style: TextStyle(
                          color: textColor.withOpacity(0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentQuestion.questionText,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      if (currentQuestion.imageUrl != null && currentQuestion.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: currentQuestion.imageUrl!.startsWith('http')
                                ? currentQuestion.imageUrl!
                                : '${ApiService.baseUrl}${currentQuestion.imageUrl}',
                            fit: BoxFit.contain,
                            height: 180,
                            placeholder: (context, url) => Center(child: CircularProgressIndicator(color: textColor)),
                            errorWidget: (context, url, error) {
                              return Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: textColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    'Хатогӣ дар боргузории сурат',
                                    style: TextStyle(color: textColor.withOpacity(0.3)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Divider(color: textColor.withOpacity(0.1), thickness: 1.5),
                      const SizedBox(height: 20),
                      _buildQuestionOptions(currentQuestion, textColor, backgroundColor),
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
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text(
                          'БА АҚИБ',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: Text(
                        isLastQuestion ? 'СУПОРИДАН' : 'НАВБАТӢ',
                        style: const TextStyle(
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
