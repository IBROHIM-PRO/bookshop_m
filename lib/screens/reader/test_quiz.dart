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
  final int? variant;

  const TestQuizScreen({super.key, required this.testId, required this.testTitle, this.variant});

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
      final url = widget.variant != null 
          ? '/api/tests/${widget.testId}?variant=${widget.variant}'
          : '/api/tests/${widget.testId}';
      final response = await ApiService.get(url);
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
              child: RichText(
                text: buildFormulaTextSpan(
                  text,
                  TextStyle(
                    color: optionTextColor,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedAnswer(QuestionModel q, Color textColor, Color backgroundColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClosedQuestionInputWidget(
          currentValue: _closedAnswers[q.id] ?? '',
          onChanged: (val) {
            setState(() {
              _closedAnswers[q.id] = val;
            });
          },
          textColor: textColor,
        ),
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
    } else if (question.questionType == 'Matching') {
      return NmtMatchingWidget(
        question: question,
        currentValue: _closedAnswers[question.id] ?? '',
        onChanged: (val) {
          setState(() {
            _closedAnswers[question.id] = val;
          });
        },
        textColor: textColor,
      );
    } else if (question.questionType == 'Multiple') {
      final selected = _multipleAnswers[question.id] ?? {};
      return Column(
        children: [
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
                      RichText(
                        text: buildFormulaTextSpan(
                          getCleanQuestionText(currentQuestion),
                          TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (currentQuestion.questionType != 'Closed' && currentQuestion.imageUrl != null && currentQuestion.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 400,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: InteractiveViewer(
                              minScale: 1.0,
                              maxScale: 3.0,
                              child: CachedNetworkImage(
                                imageUrl: currentQuestion.imageUrl!.startsWith('http')
                                    ? currentQuestion.imageUrl!
                                    : '${ApiService.baseUrl}${currentQuestion.imageUrl}',
                                fit: BoxFit.contain,
                                width: double.infinity,
                                placeholder: (context, url) => Container(
                                  height: 120,
                                  alignment: Alignment.center,
                                  child: CircularProgressIndicator(color: textColor.withOpacity(0.4)),
                                ),
                                errorWidget: (context, url, error) {
                                  return Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: textColor.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.broken_image_outlined, color: textColor.withOpacity(0.3), size: 32),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Хатогӣ дар боргузории сурат',
                                            style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
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

class ClosedQuestionInputWidget extends StatefulWidget {
  final String currentValue;
  final ValueChanged<String> onChanged;
  final Color textColor;

  const ClosedQuestionInputWidget({
    super.key,
    required this.currentValue,
    required this.onChanged,
    required this.textColor,
  });

  @override
  State<ClosedQuestionInputWidget> createState() => _ClosedQuestionInputWidgetState();
}

class _ClosedQuestionInputWidgetState extends State<ClosedQuestionInputWidget> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ClosedQuestionInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentValue != _controller.text) {
      _controller.text = widget.currentValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final paddedText = text.padLeft(4, ' ');
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Opacity(
          opacity: 0.0,
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              maxLength: 4,
              onChanged: (val) {
                final cleanVal = val.replaceAll(RegExp(r'\D'), '');
                if (cleanVal != _controller.text) {
                  _controller.value = _controller.value.copyWith(
                    text: cleanVal,
                    selection: TextSelection.collapsed(offset: cleanVal.length),
                  );
                }
                widget.onChanged(cleanVal);
              },
              decoration: const InputDecoration(
                counterText: '',
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final char = paddedText[index];
              final hasChar = char != ' ';

              return Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDarkMode 
                      ? (hasChar ? Colors.blue.withOpacity(0.15) : Colors.white.withOpacity(0.05))
                      : (hasChar ? Colors.blue.withOpacity(0.05) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasChar 
                        ? Colors.blue 
                        : (isDarkMode ? Colors.white24 : Colors.grey.shade300),
                    width: hasChar ? 2.0 : 1.0,
                  ),
                ),
                child: Text(
                  hasChar ? char : '',
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class NmtMatchingWidget extends StatefulWidget {
  final QuestionModel question;
  final String currentValue;
  final ValueChanged<String> onChanged;
  final Color textColor;

  const NmtMatchingWidget({
    super.key,
    required this.question,
    required this.currentValue,
    required this.onChanged,
    required this.textColor,
  });

  @override
  State<NmtMatchingWidget> createState() => _NmtMatchingWidgetState();
}

class _NmtMatchingWidgetState extends State<NmtMatchingWidget> {
  late Map<int, int?> _assignments;

  @override
  void initState() {
    super.initState();
    _assignments = {0: null, 1: null, 2: null, 3: null};
    _parseCurrentValue();
  }

  @override
  void didUpdateWidget(covariant NmtMatchingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentValue != oldWidget.currentValue) {
      _parseCurrentValue();
    }
  }

  void _parseCurrentValue() {
    final val = widget.currentValue;
    for (int i = 0; i < 4; i++) {
      if (i < val.length) {
        final digit = int.tryParse(val[i]);
        if (digit != null && digit >= 1 && digit <= 5) {
          _assignments[i] = digit;
          continue;
        }
      }
      _assignments[i] = null;
    }
  }

  void _saveAssignments() {
    final sb = StringBuffer();
    for (int i = 0; i < 4; i++) {
      sb.write(_assignments[i]?.toString() ?? ' ');
    }
    widget.onChanged(sb.toString().trimRight());
  }

  void _showAssignmentMenu(BuildContext context, int targetIndex) {
    final parsed = parseMatching(widget.question);
    final assignedNums = _assignments.values.whereType<int>().toSet();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Интихоби ҷавоб барои вариант: ${['А', 'Б', 'В', 'Г'][targetIndex]}',
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              ...List.generate(5, (index) {
                final num = index + 1;
                final desc = parsed.descriptions[index];
                final isCurrent = _assignments[targetIndex] == num;
                final isAssigned = assignedNums.contains(num) && !isCurrent;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrent ? Colors.blue : (isAssigned ? Colors.grey : Colors.blue.withOpacity(0.1)),
                    child: Text(
                      num.toString(),
                      style: TextStyle(
                        color: isCurrent || isAssigned ? Colors.white : Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: RichText(
                    text: buildFormulaTextSpan(
                      desc,
                      TextStyle(
                        color: isAssigned ? widget.textColor.withOpacity(0.4) : widget.textColor,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : (isAssigned ? const Text('Банд', style: TextStyle(color: Colors.grey, fontSize: 12)) : null),
                  enabled: !isAssigned,
                  onTap: () {
                    setState(() {
                      _assignments[targetIndex] = num;
                    });
                    _saveAssignments();
                    Navigator.pop(context);
                  },
                );
              }),
              if (_assignments[targetIndex] != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text(
                    'Тоза кардани интихоб',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    setState(() {
                      _assignments[targetIndex] = null;
                    });
                    _saveAssignments();
                    Navigator.pop(context);
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseMatching(widget.question);
    final assignedNums = _assignments.values.whereType<int>().toSet();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Terms (А, Б, В, Г) with drop zones ───
        ...List.generate(4, (index) {
          final term = parsed.terms[index];
          final assignedNum = _assignments[index];
          final hasAssignment = assignedNum != null;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: DragTarget<int>(
              onWillAcceptWithDetails: (details) {
                // Allow reassignment: remove from old slot if already assigned elsewhere
                return true;
              },
              onAcceptWithDetails: (details) {
                final data = details.data;
                setState(() {
                  // Remove from any previous slot
                  for (final key in _assignments.keys.toList()) {
                    if (_assignments[key] == data) {
                      _assignments[key] = null;
                    }
                  }
                  _assignments[index] = data;
                });
                _saveAssignments();
              },
              builder: (context, candidateData, rejectedData) {
                final isHovering = candidateData.isNotEmpty;
                return GestureDetector(
                  onTap: () => _showAssignmentMenu(context, index),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isHovering
                          ? (isDarkMode ? Colors.green.withOpacity(0.12) : Colors.green.withOpacity(0.05))
                          : (isDarkMode ? Colors.white.withOpacity(0.04) : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isHovering
                            ? Colors.green
                            : (hasAssignment
                                ? Colors.blue.withOpacity(0.4)
                                : (isDarkMode ? Colors.white12 : Colors.grey.shade300)),
                        width: isHovering ? 2.0 : 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Term letter (А, Б, В, Г)
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1.5),
                          ),
                          child: Text(
                            ['А', 'Б', 'В', 'Г'][index],
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Term text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: buildFormulaTextSpan(
                                  term,
                                  TextStyle(
                                    color: widget.textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Drop zone / assigned number
                        GestureDetector(
                          onTap: hasAssignment
                              ? () {
                                  setState(() {
                                    _assignments[index] = null;
                                  });
                                  _saveAssignments();
                                }
                              : null,
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: hasAssignment
                                  ? Colors.blue
                                  : (isHovering
                                      ? Colors.green.withOpacity(0.2)
                                      : (isDarkMode ? Colors.white.withOpacity(0.06) : Colors.grey.shade200)),
                              borderRadius: BorderRadius.circular(12),
                              border: hasAssignment
                                  ? null
                                  : Border.all(
                                      color: isHovering ? Colors.green : Colors.transparent,
                                      width: 1.5,
                                    ),
                            ),
                            child: hasAssignment
                                ? Text(
                                    assignedNum.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : Icon(
                                    Icons.add,
                                    color: isHovering ? Colors.green : Colors.grey,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }),
        const SizedBox(height: 20),
        // ─── Answer options (1-5) as draggable number chips ───
        Text(
          'Вариантҳои ҷавоб:',
          style: TextStyle(
            color: widget.textColor.withOpacity(0.6),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(5, (index) {
          final num = index + 1;
          final descText = parsed.descriptions[index];
          final isAssigned = assignedNums.contains(num);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Opacity(
              opacity: isAssigned ? 0.4 : 1.0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Draggable number chip
                  isAssigned
                      ? Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            num.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Draggable<int>(
                          data: num,
                          feedback: Material(
                            color: Colors.transparent,
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                num.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.withOpacity(0.3), style: BorderStyle.solid),
                            ),
                            child: Text(
                              num.toString(),
                              style: TextStyle(
                                color: Colors.blue.withOpacity(0.3),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.blue.withOpacity(0.15) : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1.5),
                            ),
                            child: Text(
                              num.toString(),
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(width: 10),
                  // Description text
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: RichText(
                        text: buildFormulaTextSpan(
                          descText,
                          TextStyle(
                            color: widget.textColor,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class ParsedMatchingQuestion {
  final List<String> terms;
  final List<String> descriptions;

  ParsedMatchingQuestion({required this.terms, required this.descriptions});
}

ParsedMatchingQuestion parseMatching(QuestionModel question) {
  final terms = [
    question.optionA.trim(),
    question.optionB.trim(),
    question.optionC.trim(),
    question.optionD.trim(),
  ];

  final descriptions = <String>[];
  final text = question.questionText;

  final pattern = RegExp(r'(?:^|\s)(?:[1-5]\s*[\)\.\-\s]\s*)(.+?)(?=\s*[1-5]\s*[\)\.\-\s]\s*|$)');
  final matches = pattern.allMatches(text);

  for (final m in matches) {
    if (m.groupCount >= 1) {
      final desc = m.group(1)!.trim();
      descriptions.add(desc);
    }
  }

  if (descriptions.length < 5) {
    descriptions.clear();
    final lines = text.split('\n');
    for (final line in lines) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;
      if (RegExp(r'^[1-5]\s*[\)\.\-\s]').hasMatch(cleanLine)) {
        final content = cleanLine.replaceFirst(RegExp(r'^[1-5]\s*[\)\.\-\s]\s*'), '').trim();
        descriptions.add(content);
      }
    }
  }

  while (descriptions.length < 5) {
    descriptions.add('Варианти ҷавоб ${descriptions.length + 1}');
  }

  for (int i = 0; i < terms.length; i++) {
    final t = terms[i];
    terms[i] = t.replaceFirst(RegExp(r'^[А-Яа-яA-Za-z]\s*[\)\.\-\s]\s*'), '').trim();
  }

  return ParsedMatchingQuestion(
    terms: terms,
    descriptions: descriptions.sublist(0, 5),
  );
}

String getCleanQuestionText(QuestionModel question) {
  final text = question.questionText;
  String cleaned = text.replaceAll(RegExp(r'\b(w\s*w|tc|ntc|Саҳифаи\s*\d+)\b', caseSensitive: false), '');

  final firstDescIndex = cleaned.indexOf(RegExp(r'(?:^|\s)[1-5]\s*[\)\.\-\s]'));
  if (firstDescIndex != -1) {
    cleaned = cleaned.substring(0, firstDescIndex).trim();
  }

  return cleaned.trim();
}

/// Renders text with proper formula formatting for physics and chemistry.
///
/// Handles:
/// - Chemistry: H2O → H₂O, CO2 → CO₂, H2SO4 → H₂SO₄, Ca(OH)2 → Ca(OH)₂
/// - Physics units: м/с2 → м/с², см2 → см², м3 → м³, кг/м3 → кг/м³
/// - Powers of 10: 10^15 or contextual like "·1015" → 10¹⁵
/// - Explicit caret: x^2 → x², v^2 → v²
/// - Unicode sub/superscripts: ₂ → subscript 2, ² → superscript 2
/// - Square root: √ rendered properly
TextSpan buildFormulaTextSpan(String text, TextStyle baseStyle) {
  final List<InlineSpan> spans = [];
  String normalized = _normalizeMathChars(text);

  final double baseSize = baseStyle.fontSize ?? 16.0;
  final TextStyle subStyle = baseStyle.copyWith(fontSize: baseSize * 0.7);
  final TextStyle superStyle = baseStyle.copyWith(fontSize: baseSize * 0.7);

  // Tokenize using regex — order matters: longer/more-specific patterns first.
  // Each pattern has a named group so we know what matched.
  final tokenPattern = RegExp(
    // 1. Physics units with trailing digit as superscript
    r'(?<unit>(?:кг/м|м/с|м/c|Н/м|Дж/кг|Вт/м|Н·м|Па·с|А/м|кг·м/с|см|мм|дм|км|м|с|c|Н)(?=[23](?![0-9])))'
    r'(?<unitExp>[23])'
    // 2. Explicit caret notation: x^2, v^(2n), T^(-1)
    r'|(?<caretBase>[A-Za-zА-Яа-яЁёҒғҚқҶҷӮӯӢӣҲҳ0-9])\^(?:\((?<caretParenExp>[^)]+)\)|(?<caretExp>[A-Za-zА-Яа-яЁёҒғҚқҶҷӮӯӢӣҲҳ0-9+\-]+))'
    // 3. Power of 10 with explicit caret: 10^15, 10^-19, 10^(23)
    r'|10\^(?:\((?<tenParenExp>[^)]+)\)|(?<tenCaretExp>-?\d+))'
    // 4. Power of 10 inline (e.g. "·1015" or "∙1023" context)
    r'|(?<tenDot>[·∙×⋅]\s*)10(?<tenDotExp>\d{1,3})(?![0-9])'
    // 5. Chemical formula: Element symbol(s) followed by digits as subscripts
    //    Matches: H2, O2, H2O, CO2, H2SO4, Ca(OH)2, Fe2O3, Na2CO3, CH3COOH, C2H5OH, C6H12O6
    r'|(?<chemElem>[A-Z][a-z]?)(?<chemSub>\d+)'
    // 6. Parenthesized group with subscript in chemistry: (OH)2, (NO3)2, (SO4)3
    r'|(?<chemParen>\([A-Z][a-z]?(?:\d+)?(?:[A-Z][a-z]?(?:\d+)?)*\))(?<chemParenSub>\d+)'
    // 7. Unicode subscript characters
    r'|(?<uniSub>[₀₁₂₃₄₅₆₇₈₉]+)'
    // 8. Unicode superscript characters
    r'|(?<uniSup>[⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻]+)'
    // 9. Square root symbol
    r'|(?<sqrt>√)'
    // 10. Normal text (anything else, batch it)
    r'|(?<normal>[^A-Z₀₁₂₃₄₅₆₇₈₉⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻√\^·∙×⋅]+)'
    // 11. Single unmatched character fallback
    r'|(?<other>.)',
    unicode: true,
    caseSensitive: true,
  );

  // Maps for unicode sub/superscripts
  const subMap = {
    '₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4',
    '₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9',
  };
  const superMap = {
    '⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4',
    '⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9',
    '⁺': '+', '⁻': '-',
  };

  WidgetSpan _makeSuperscript(String txt) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Transform.translate(
        offset: const Offset(0, -6),
        child: Text(txt, style: superStyle),
      ),
    );
  }

  WidgetSpan _makeSubscript(String txt) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Transform.translate(
        offset: const Offset(0, 4),
        child: Text(txt, style: subStyle),
      ),
    );
  }

  // We need a smarter approach: scan with the regex but also check context.
  // The tokenPattern is case-sensitive and matches upper-case element symbols.
  // For lower-case-only text or Cyrillic text followed by digits, we do NOT subscript.
  
  // However, the above regex is case-sensitive which means only uppercase Latin
  // letters (element symbols) trigger chemElem. We need a second pass for
  // Cyrillic physics variables (like Р1, F1) — but those are rarer.
  // We'll handle them with the caret notation instead.

  // Let's just iterate through the normalized text using the regex.
  int lastEnd = 0;
  
  for (final match in tokenPattern.allMatches(normalized)) {
    // If there's a gap between last match and this match, add as normal text
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: normalized.substring(lastEnd, match.start), style: baseStyle));
    }
    
    if (match.namedGroup('unit') != null) {
      // Physics unit + superscript exponent
      spans.add(TextSpan(text: match.namedGroup('unit')!, style: baseStyle));
      spans.add(_makeSuperscript(match.namedGroup('unitExp')!));
    } else if (match.namedGroup('caretBase') != null) {
      // Explicit caret: x^2 or x^(2n)
      spans.add(TextSpan(text: match.namedGroup('caretBase')!, style: baseStyle));
      final exp = match.namedGroup('caretParenExp') ?? match.namedGroup('caretExp')!;
      spans.add(_makeSuperscript(exp));
    } else if (match.namedGroup('tenCaretExp') != null) {
      // 10^15
      spans.add(TextSpan(text: '10', style: baseStyle));
      spans.add(_makeSuperscript(match.namedGroup('tenCaretExp')!));
    } else if (match.namedGroup('tenParenExp') != null) {
      // 10^(23)
      spans.add(TextSpan(text: '10', style: baseStyle));
      spans.add(_makeSuperscript(match.namedGroup('tenParenExp')!));
    } else if (match.namedGroup('tenDot') != null) {
      // ·10^15 (contextual)
      spans.add(TextSpan(text: match.namedGroup('tenDot')!, style: baseStyle));
      spans.add(TextSpan(text: '10', style: baseStyle));
      spans.add(_makeSuperscript(match.namedGroup('tenDotExp')!));
    } else if (match.namedGroup('chemParen') != null) {
      // (OH)2 → (OH)₂
      spans.add(TextSpan(text: match.namedGroup('chemParen')!, style: baseStyle));
      spans.add(_makeSubscript(match.namedGroup('chemParenSub')!));
    } else if (match.namedGroup('chemElem') != null) {
      // Chemical element + subscript: H2, O3, etc.
      spans.add(TextSpan(text: match.namedGroup('chemElem')!, style: baseStyle));
      spans.add(_makeSubscript(match.namedGroup('chemSub')!));
    } else if (match.namedGroup('uniSub') != null) {
      // Unicode subscript chars
      final chars = match.namedGroup('uniSub')!;
      final mapped = chars.split('').map((c) => subMap[c] ?? c).join();
      spans.add(_makeSubscript(mapped));
    } else if (match.namedGroup('uniSup') != null) {
      // Unicode superscript chars
      final chars = match.namedGroup('uniSup')!;
      final mapped = chars.split('').map((c) => superMap[c] ?? c).join();
      spans.add(_makeSuperscript(mapped));
    } else if (match.namedGroup('sqrt') != null) {
      spans.add(TextSpan(text: '√', style: baseStyle.copyWith(
        fontWeight: FontWeight.bold,
      )));
    } else {
      // normal or other — just add as text
      spans.add(TextSpan(text: match.group(0)!, style: baseStyle));
    }
    
    lastEnd = match.end;
  }
  
  // Add any remaining text
  if (lastEnd < normalized.length) {
    spans.add(TextSpan(text: normalized.substring(lastEnd), style: baseStyle));
  }

  if (spans.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }

  return TextSpan(children: spans);
}

/// Normalizes mathematical alphanumeric Unicode symbols back to standard ASCII.
/// PDF text extraction often produces these bold/italic math variants.
String _normalizeMathChars(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    // Mathematical Bold Digits: 𝟎-𝟗 (0x1D7CE–0x1D7D7)
    if (rune >= 0x1D7CE && rune <= 0x1D7D7) {
      buffer.writeCharCode(0x30 + (rune - 0x1D7CE));
    }
    // Mathematical Bold Capitals: 𝐀-𝐙 (0x1D400–0x1D419)
    else if (rune >= 0x1D400 && rune <= 0x1D419) {
      buffer.writeCharCode(0x41 + (rune - 0x1D400));
    }
    // Mathematical Bold Small: 𝐚-𝐳 (0x1D41A–0x1D433)
    else if (rune >= 0x1D41A && rune <= 0x1D433) {
      buffer.writeCharCode(0x61 + (rune - 0x1D41A));
    }
    // Mathematical Italic Capitals: 𝐴-𝑍 (0x1D434–0x1D44D)
    else if (rune >= 0x1D434 && rune <= 0x1D44D) {
      buffer.writeCharCode(0x41 + (rune - 0x1D434));
    }
    // Mathematical Italic Small: 𝑎-𝑧 (0x1D44E–0x1D467)
    else if (rune >= 0x1D44E && rune <= 0x1D467) {
      buffer.writeCharCode(0x61 + (rune - 0x1D44E));
    }
    // Mathematical Bold Italic Capitals: 𝑨-𝒁 (0x1D468–0x1D481)
    else if (rune >= 0x1D468 && rune <= 0x1D481) {
      buffer.writeCharCode(0x41 + (rune - 0x1D468));
    }
    // Mathematical Bold Italic Small: 𝒂-𝒛 (0x1D482–0x1D49B)
    else if (rune >= 0x1D482 && rune <= 0x1D49B) {
      buffer.writeCharCode(0x61 + (rune - 0x1D482));
    }
    // Mathematical Sans-Serif Bold Digits: 𝟬-𝟵 (0x1D7EC–0x1D7F5)
    else if (rune >= 0x1D7EC && rune <= 0x1D7F5) {
      buffer.writeCharCode(0x30 + (rune - 0x1D7EC));
    }
    // Mathematical Sans-Serif Digits: 𝟢-𝟫 (0x1D7E2–0x1D7EB)
    else if (rune >= 0x1D7E2 && rune <= 0x1D7EB) {
      buffer.writeCharCode(0x30 + (rune - 0x1D7E2));
    }
    // Mathematical Double-Struck Digits: 𝟘-𝟡 (0x1D7D8–0x1D7E1)
    else if (rune >= 0x1D7D8 && rune <= 0x1D7E1) {
      buffer.writeCharCode(0x30 + (rune - 0x1D7D8));
    }
    // Mathematical Monospace Digits: 𝟶-𝟿 (0x1D7F6–0x1D7FF)
    else if (rune >= 0x1D7F6 && rune <= 0x1D7FF) {
      buffer.writeCharCode(0x30 + (rune - 0x1D7F6));
    }
    else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}
