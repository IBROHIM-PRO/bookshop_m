import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../login_screen.dart';
import '../notifications_feed.dart';
import 'create_test_screen.dart';
import 'student_results_screen.dart';
import 'package:file_picker/file_picker.dart';
import '../chat/chat_list_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 1;
  List<dynamic> _students = [];
  List<dynamic> _tests = [];
  List<dynamic> _pendingAttempts = [];
  List<dynamic> _paperTests = [];
  bool _isLoadingStudents = true;
  bool _isLoadingTests = true;
  bool _isLoadingAttempts = true;
  bool _isLoadingPaper = true;
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });
    _fetchStudents();
    _fetchTests();
    _fetchPendingAttempts();
    _fetchPaperTests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchPaperTests() async {
    setState(() {
      _isLoadingPaper = true;
    });
    try {
      final response = await ApiService.get('/api/tests/paper');
      if (response.statusCode == 200) {
        setState(() {
          _paperTests = jsonDecode(response.body);
          _isLoadingPaper = false;
        });
      } else {
        setState(() {
          _isLoadingPaper = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingPaper = false;
      });
    }
  }

  String _cleanTitle(String title) {
    final t = title.trim();
    if (t.toLowerCase() == 'уқуқ') return 'Ҳуқуқи инсон';
    if (t.toLowerCase() == 'вчаҷв') return 'Таърихи халқи тоҷик';
    return title;
  }

  String _getFullImageUrl(String? url) {
    return ApiService.getFullImageUrl(url);
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<void> _pickAndUploadStudentAvatar(int studentId) async {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final snackBarBg = isDarkMode ? Colors.white : Colors.black;
    final snackBarFg = isDarkMode ? Colors.black : Colors.white;

    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result == null || result.files.single.path == null) return;

      final pickedFile = result.files.single;

      if (pickedFile.size > 1 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ҳаҷми расм набояд аз 1 МБ зиёд бошад!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Расм боргузорӣ шуда истодааст...'),
            backgroundColor: snackBarBg,
            duration: const Duration(seconds: 1),
          ),
        );
      }

      final response = await ApiService.uploadAvatar(pickedFile.path!, pickedFile.name, userId: studentId);
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Расми профил бомуваффақият боргузорӣ шуд!'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchStudents();
        }
      } else {
        final resData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resData['message'] ?? 'Хатогӣ дар боргузории расм'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Хатогии пайвастшавӣ бо сервер'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoadingStudents = true;
    });
    try {
      final response = await ApiService.get('/api/teacher/students');
      if (response.statusCode == 200) {
        setState(() {
          _students = jsonDecode(response.body);
          _isLoadingStudents = false;
        });
      } else {
        setState(() => _isLoadingStudents = false);
      }
    } catch (e) {
      setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _fetchTests() async {
    setState(() {
      _isLoadingTests = true;
    });
    try {
      final response = await ApiService.get('/api/tests');
      if (response.statusCode == 200) {
        setState(() {
          _tests = jsonDecode(response.body);
          _isLoadingTests = false;
        });
      } else {
        setState(() => _isLoadingTests = false);
      }
    } catch (e) {
      setState(() => _isLoadingTests = false);
    }
  }

  Future<void> _fetchPendingAttempts() async {
    setState(() {
      _isLoadingAttempts = true;
    });
    try {
      final response = await ApiService.get('/api/tests/attempts/pending');
      if (response.statusCode == 200) {
        setState(() {
          _pendingAttempts = jsonDecode(response.body);
          _isLoadingAttempts = false;
        });
      } else {
        setState(() => _isLoadingAttempts = false);
      }
    } catch (e) {
      setState(() => _isLoadingAttempts = false);
    }
  }



  void _showStudentStats(int studentId, String studentName) async {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return FutureBuilder(
              future: ApiService.get('/api/teacher/student/$studentId/statistics'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: textColor));
                }
                if (snapshot.hasError || snapshot.data?.statusCode != 200) {
                  return Center(child: Text('Хатогӣ дар боркунии омор', style: TextStyle(color: textColor)));
                }

                final stats = jsonDecode(snapshot.data!.body);
                final attempts = stats['testAttempts'] as List;

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: textColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Омори пешрафти $studentName',
                      style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Китобҳои дастрас',
                            '${stats['booksReadCount']}',
                            Icons.menu_book,
                            textColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Холҳои миёна',
                            '${stats['averageScorePercentage']}%',
                            Icons.analytics,
                            textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Таърихи супоридани тестҳо',
                      style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (attempts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'То ҳол тестҳо супорида нашудаанд',
                            style: TextStyle(color: textColor.withOpacity(0.5)),
                          ),
                        ),
                      )
                    else
                      ...attempts.map((a) {
                        final isGraded = a['isGraded'] ?? true;
                        final percent = (a['percentage'] as num).toDouble();
                        final isPassed = percent >= 50.0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: textColor.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a['testTitle'],
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    if (isGraded)
                                      Text(
                                        'Хол: ${a['score']}/${a['totalQuestions']}',
                                        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13),
                                      )
                                    else
                                      Text(
                                        'Холҳои вариантӣ: ${a['optionEarnedPoints'] ?? a['earnedPoints']} аз ${a['optionTotalPoints'] ?? a['totalPoints']}',
                                        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold),
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
                              ),
                              if (isGraded)
                                Text(
                                  '${percent.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: isPassed ? Colors.green : Colors.redAccent,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: textColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Тафтиш',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showGradingBottomSheet(int attemptId) async {
    final response = await ApiService.get('/api/tests/attempts/$attemptId');
    if (!mounted) return;
    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хатогӣ дар боркунии маълумот'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final attemptDetail = jsonDecode(response.body);
    final answers = attemptDetail['answers'] as List;

    final Map<int, int> tempGrades = {};
    final Map<int, TextEditingController> controllers = {};

    for (var ans in answers) {
      if (ans['questionType'] == 'Closed') {
        final answerId = ans['answerId'];
        tempGrades[answerId] = ans['earnedPoints'] ?? 0;
        controllers[answerId] = TextEditingController(text: '${tempGrades[answerId]}');
      }
    }

    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void submitGrades() async {
              bool hasValidationError = false;
              String errorMessage = '';

              for (var ans in answers) {
                if (ans['questionType'] == 'Closed') {
                  final answerId = ans['answerId'];
                  final int maxPoints = ans['maxPoints'] ?? 10;
                  final textValue = controllers[answerId]?.text.trim() ?? '';

                  if (textValue.isEmpty) {
                    hasValidationError = true;
                    errorMessage = 'Лутфан балли саволро ворид кунед.';
                    break;
                  }

                  final points = int.tryParse(textValue);
                  if (points == null) {
                    hasValidationError = true;
                    errorMessage = 'Лутфан танҳо рақам ворид кунед.';
                    break;
                  }

                  if (points < 0 || points > maxPoints) {
                    hasValidationError = true;
                    errorMessage = 'Балл наметавонад аз $maxPoints зиёд ё аз 0 кам бошад.';
                    break;
                  }

                  tempGrades[answerId] = points;
                }
              }

              if (hasValidationError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent),
                );
                return;
              }

              setModalState(() {
              });
              
              final payload = {
                'grades': tempGrades.entries.map((e) => {
                  'answerId': e.key,
                  'earnedPoints': e.value,
                }).toList(),
              };

              try {
                final res = await ApiService.post('/api/tests/attempts/$attemptId/grade', payload);
                if (res.statusCode == 200) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Баҳодиҳӣ бомуваффақият захира шуд.'), backgroundColor: Colors.black),
                  );
                  Navigator.of(ctx).pop();
                  _fetchPendingAttempts();
                  _fetchStudents();
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Хатогӣ ҳангоми захираи баҳо')),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Хатогӣ дар пайвастшавӣ ба сервер')),
                );
              } finally {
                setModalState(() {
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: DraggableScrollableSheet(
                initialChildSize: 0.75,
                maxChildSize: 0.9,
                minChildSize: 0.5,
                expand: false,
                builder: (_, scrollController) {
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: textColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Тафтиш: ${attemptDetail['studentName']}',
                        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Тест: ${attemptDetail['testTitle']}',
                        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14),
                      ),
                      const SizedBox(height: 20),

                      ...answers.map((ans) {
                        final bool isClosed = ans['questionType'] == 'Closed';
                        final int maxPoints = ans['maxPoints'] ?? 10;
                        final int answerId = ans['answerId'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: textColor.withOpacity(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: textColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      ans['questionType'] == 'TrueFalse'
                                          ? 'Рост/Дурӯғ'
                                          : (isClosed ? 'Саволи Хаттӣ' : 'Интихобӣ'),
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (!isClosed)
                                    Text(
                                      'Балл: ${ans['earnedPoints']} / $maxPoints',
                                      style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold),
                                    )
                                  else
                                    Row(
                                      children: [
                                        Text('Балл: ', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
                                        SizedBox(
                                          width: 60,
                                          height: 35,
                                          child: TextField(
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                            controller: controllers[answerId],
                                            scrollPadding: const EdgeInsets.all(120),
                                            decoration: InputDecoration(
                                              contentPadding: EdgeInsets.zero,
                                              fillColor: textColor.withOpacity(0.05),
                                              filled: true,
                                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: textColor.withOpacity(0.2)), borderRadius: BorderRadius.circular(8)),
                                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textColor, width: 1.5), borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ),
                                        Text(' / $maxPoints', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                ans['questionText'],
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: textColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ҷавоби донишҷӯ:',
                                      style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    (() {
                                      final studentAnswer = ans['studentAnswer'] ?? '';
                                      final isFile = studentAnswer.contains('/uploads/') || 
                                                     studentAnswer.startsWith('http://') || 
                                                     studentAnswer.startsWith('https://');
                                      if (isFile) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: ElevatedButton.icon(
                                              onPressed: () async {
                                                final fileUrl = ApiService.getFullImageUrl(studentAnswer);
                                                final uri = Uri.parse(fileUrl);
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                } else {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Файлро кушода нашуд')),
                                                    );
                                                  }
                                                }
                                              },
                                              icon: Icon(Icons.open_in_new, size: 16, color: isDarkMode ? Colors.black : Colors.white),
                                              label: const Text('Кушодани файл'),
                                            ),
                                          ),
                                        );
                                      } else {
                                        return Text(
                                          studentAnswer.isNotEmpty ? studentAnswer : 'Ҷавоб дода нашудааст',
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 13,
                                            fontWeight: isClosed ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        );
                                      }
                                    })(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: submitGrades,
                        child: const Text('Тасдиқи баҳоҳо ва фиристодан'),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentsList() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoadingStudents) {
      return Center(child: CircularProgressIndicator(color: textColor));
    }

    if (_students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: textColor.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'Ҳеҷ донишҷӯ пайваст карда нашудааст',
                style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Пайвасткунии хонандагон танҳо аз тарафи админ иҷро карда мешавад',
                style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _students.length,
        itemBuilder: (context, index) {
          final student = _students[index];

          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentResultsScreen(
                    studentId: student['id'],
                    studentName: student['name'],
                    studentEmail: student['email'] ?? '',
                  ),
                ),
              ).then((_) {
                _fetchStudents();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? Theme.of(context).cardColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode ? Colors.white10 : const Color(0xFF1E7431).withOpacity(0.15),
                ),
                boxShadow: isDarkMode ? [] : [
                  BoxShadow(
                    color: const Color(0xFF228B22).withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkMode ? Colors.white24 : const Color(0xFF1E7431).withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                                radius: 24,
                                backgroundColor: isDarkMode ? Colors.white12 : const Color(0xFFEBF3ED),
                                backgroundImage: student['imageUrl'] != null && student['imageUrl'].toString().isNotEmpty
                                    ? CachedNetworkImageProvider(_getFullImageUrl(student['imageUrl'].toString()))
                                    : null,
                                child: student['imageUrl'] != null && student['imageUrl'].toString().isNotEmpty
                                    ? null
                                    : Text(
                                        _getInitials(student['name']),
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white : const Color(0xFF1E7431),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name'],
                                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                student['groupName']?.toString().isNotEmpty == true ? student['groupName'] : (student['email'] ?? 'Бе гурӯҳ'),
                                style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_forward_ios, color: textColor.withOpacity(0.3), size: 16),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradingList() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoadingAttempts) {
      return Center(child: CircularProgressIndicator(color: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431)));
    }

    if (_pendingAttempts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1A241D) : const Color(0xFFEBF3ED),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 48, color: Color(0xFF228B22)),
            ),
            const SizedBox(height: 16),
            Text(
              'Ҳамаи тестҳо тафтиш шудаанд!',
              style: TextStyle(color: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingAttempts.length,
      itemBuilder: (context, index) {
        final attempt = _pendingAttempts[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Theme.of(context).cardColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.white10 : const Color(0xFF1E7431).withOpacity(0.15),
            ),
            boxShadow: isDarkMode ? [] : [
              BoxShadow(
                color: const Color(0xFF228B22).withOpacity(0.04),
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
                      attempt['studentName'],
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      attempt['studentEmail'],
                      style: TextStyle(color: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _cleanTitle(attempt['testTitle'] ?? ''),
                      style: TextStyle(color: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _showGradingBottomSheet(attempt['attemptId']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E7431),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: const Text('Тафтиш'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTestsList() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431),
            labelColor: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431),
            unselectedLabelColor: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367),
            tabs: const [
              Tab(text: 'Тестҳои онлайн'),
              Tab(text: 'Тестҳои қоғазӣ'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOnlineTestsTab(isDarkMode),
                _buildPaperTestsTab(isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineTestsTab(bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoadingTests) {
      return Center(child: CircularProgressIndicator(color: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431)));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _tests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_outlined, size: 64, color: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367)),
                  const SizedBox(height: 16),
                  Text(
                    'Ҳеҷ тест сохта нашудааст',
                    style: TextStyle(color: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchTests,
              color: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tests.length,
                itemBuilder: (context, index) {
                  final test = _tests[index];
                  final List questions = test['questions'] ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Theme.of(context).cardColor : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDarkMode ? Colors.white10 : const Color(0xFF1E7431).withOpacity(0.15),
                      ),
                      boxShadow: isDarkMode ? [] : [
                        BoxShadow(
                          color: const Color(0xFF228B22).withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _cleanTitle(test['title'] ?? ''),
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${questions.length} савол • ${test['description'] ?? "Имтиҳон"}',
                        style: TextStyle(color: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367), fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            onPressed: () async {
                              final res = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CreateTestScreen(testId: test['id']),
                                ),
                              );
                              if (res == true) {
                                _fetchTests();
                              }
                            },
                          ),
                          Icon(Icons.quiz, color: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'create_test_fab',
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateTestScreen()),
          );
          if (res == true) {
            _fetchTests();
          }
        },
        backgroundColor: const Color(0xFF1E7431),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPaperTestsTab(bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoadingPaper) {
      return Center(child: CircularProgressIndicator(color: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431)));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _paperTests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 64, color: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367)),
                  const SizedBox(height: 16),
                  Text(
                    'Ҳеҷ натиҷаи қоғазӣ ворид нашудааст',
                    style: TextStyle(color: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchPaperTests,
              color: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _paperTests.length,
                itemBuilder: (context, index) {
                  final result = _paperTests[index];
                  final studentName = result['studentName'] ?? '';
                  final subject = result['subject'] ?? '';
                  final score = result['score'] ?? 0;
                  final dateStr = result['dateCreated'] != null
                      ? DateTime.parse(result['dateCreated']).toLocal().toString().split(' ')[0]
                      : '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Theme.of(context).cardColor : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDarkMode ? Colors.white10 : const Color(0xFF1E7431).withOpacity(0.15),
                      ),
                      boxShadow: isDarkMode ? [] : [
                        BoxShadow(
                          color: const Color(0xFF228B22).withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        studentName,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$subject • Хол: $score балл • Сана: $dateStr',
                        style: TextStyle(color: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367), fontSize: 13),
                      ),
                      trailing: Icon(
                        Icons.assignment, 
                        color: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431)
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'create_paper_test_fab',
        onPressed: _showAddPaperTestDialog,
        backgroundColor: const Color(0xFF1E7431),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _deletePaperTestResult(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Нест кардан'),
        content: const Text('Оё мехоҳед ин натиҷаро нест кунед?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Бекор'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Нест кардан', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiService.delete('/api/tests/paper/$id');
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Натиҷа бомуваффақият нест карда шуд.'), backgroundColor: Colors.black),
        );
        _fetchPaperTests();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Хатогӣ дар нест кардан'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хатогӣ дар нест кардан'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showAddPaperTestDialog() async {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? const Color(0xFF162218) : Colors.white;

    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    final scoreController = TextEditingController();
    int? selectedStudentId;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: backgroundColor,
              title: Text('Сабти натиҷаи тести қоғазӣ', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      dropdownColor: backgroundColor,
                      decoration: InputDecoration(
                        labelText: 'Пайваст ба донишҷӯ (ихтиёрӣ)',
                        labelStyle: TextStyle(color: textColor.withOpacity(0.6)),
                      ),
                      value: selectedStudentId,
                      items: _students.map<DropdownMenuItem<int>>((s) {
                        return DropdownMenuItem<int>(
                          value: s['id'] as int,
                          child: Text(s['name'] ?? '', style: TextStyle(color: textColor)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedStudentId = val;
                          if (val != null) {
                            final selected = _students.firstWhere((s) => s['id'] == val);
                            nameController.text = selected['name'] ?? '';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Номи хонанда',
                        labelStyle: TextStyle(color: textColor.withOpacity(0.6)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Фанни имтиҳон',
                        labelStyle: TextStyle(color: textColor.withOpacity(0.6)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: scoreController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Балл (Хол)',
                        labelStyle: TextStyle(color: textColor.withOpacity(0.6)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Бекор', style: TextStyle(color: textColor.withOpacity(0.6))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final subject = subjectController.text.trim();
                    final scoreVal = scoreController.text.trim();

                    if (name.isEmpty || subject.isEmpty || scoreVal.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Лутфан тамоми майдонҳоро пур кунед!')),
                      );
                      return;
                    }

                    final score = int.tryParse(scoreVal);
                    if (score == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Балл бояд рақам бошад!')),
                      );
                      return;
                    }

                    Navigator.of(ctx).pop();

                    try {
                      final response = await ApiService.post('/api/tests/paper', {
                        'studentName': name,
                        'subject': subject,
                        'score': score,
                        'studentId': selectedStudentId,
                      });

                      if (response.statusCode == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Натиҷа бомуваффақият сабт шуд.'),
                            backgroundColor: Colors.black,
                          ),
                        );
                        _fetchPaperTests();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Хатогӣ дар сабти натиҷа'), backgroundColor: Colors.redAccent),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Хатогӣ дар сабти натиҷа'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                  child: const Text('Захира'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _logout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacher = Provider.of<AuthProvider>(context).currentUser;
    final teacherName = teacher?.name ?? 'Муаллим';
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoadingStudents || _isLoadingTests || _isLoadingAttempts) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF0D120E) : const Color(0xFFF1F8F4),
        body: Center(
          child: CircularProgressIndicator(
            color: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0D120E) : const Color(0xFFF1F8F4),
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teacherName,
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Панели назорати муаллим',
              style: TextStyle(color: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367), fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/logo/logoheader/Group 44375.svg',
              height: 24,
            ),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatListScreen()));
            },
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/logo/logoheader/Frame 1984078266.svg',
              height: 28,
            ),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsFeedScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStudentsList(),
          _buildGradingList(),
          _buildTestsList(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            _tabController.animateTo(index);
          });
        },
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        selectedItemColor: const Color(0xFF1E7431),
        unselectedItemColor: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/logo/teacher_grading.png',
              height: 24,
              color: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367),
              colorBlendMode: BlendMode.srcIn,
            ),
            activeIcon: Image.asset(
              'assets/logo/teacher_grading.png',
              height: 24,
              color: const Color(0xFF1E7431),
              colorBlendMode: BlendMode.srcIn,
            ),
            label: 'Студентҳо',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('${_pendingAttempts.length}'),
              isLabelVisible: _pendingAttempts.isNotEmpty,
              backgroundColor: const Color(0xFF1E7431),
              child: SvgPicture.asset(
                'assets/logo/teacher_tests.svg',
                height: 24,
                colorFilter: ColorFilter.mode(
                  isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367),
                  BlendMode.srcIn,
                ),
              ),
            ),
            activeIcon: Badge(
              label: Text('${_pendingAttempts.length}'),
              isLabelVisible: _pendingAttempts.isNotEmpty,
              backgroundColor: const Color(0xFF1E7431),
              child: SvgPicture.asset(
                'assets/logo/teacher_tests.svg',
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF1E7431),
                  BlendMode.srcIn,
                ),
              ),
            ),
            label: 'Тафтиш',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/logo/teacher_students.svg',
              height: 24,
              colorFilter: ColorFilter.mode(
                isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF657367),
                BlendMode.srcIn,
              ),
            ),
            activeIcon: SvgPicture.asset(
              'assets/logo/teacher_students.svg',
              height: 24,
              colorFilter: const ColorFilter.mode(
                Color(0xFF1E7431),
                BlendMode.srcIn,
              ),
            ),
            label: 'Тестҳо',
          ),
        ],
      ),
    );
  }
}
