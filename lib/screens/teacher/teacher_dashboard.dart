import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../login_screen.dart';
import '../notifications_feed.dart';
import 'create_test_screen.dart';
import 'student_results_screen.dart';
import 'package:file_picker/file_picker.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _students = [];
  List<dynamic> _tests = [];
  List<dynamic> _pendingAttempts = [];
  bool _isLoadingStudents = true;
  bool _isLoadingTests = true;
  bool _isLoadingAttempts = true;
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchStudents();
    _fetchTests();
    _fetchPendingAttempts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _getFullImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiService.baseUrl}$url';
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
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.single.path == null) return;

      final pickedFile = result.files.single;

      // Enforce 1MB size limit
      if (pickedFile.size > 1 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ҳаҷми расм набояд аз 1 МБ зиёд бошад!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Расм боргузорӣ шуда истодааст...'),
            duration: Duration(seconds: 1),
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
        setState(() {
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingStudents = false;
      });
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
        setState(() {
          _isLoadingTests = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingTests = false;
      });
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
        setState(() {
          _isLoadingAttempts = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingAttempts = false;
      });
    }
  }

  void _linkStudent() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Лутфан email-и дуруст ворид созед')),
      );
      return;
    }

    Navigator.of(context).pop(); // Close dialog
    setState(() {
      _isLoadingStudents = true;
    });

    try {
      final response = await ApiService.post('/api/teacher/link-student', {
        'studentEmail': email,
      });

      if (response.statusCode == 200) {
        _emailController.clear();
        _fetchStudents();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Донишҷӯ бомуваффақият пайваст карда шуд.'), backgroundColor: Colors.teal),
        );
      } else {
        final err = jsonDecode(response.body);
        setState(() {
          _isLoadingStudents = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['message'] ?? 'Хатогӣ дар пайвасткунии донишҷӯ'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingStudents = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хатогӣ дар пайвастшавӣ ба сервер'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showLinkStudentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E173E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Пайваст кардани донишҷӯ', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Почтаи электронии (email) донишҷӯро, ки ҳамчун Хонанда ба қайд гирифта шудааст, ворид кунед:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Email-и хонанда',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Бекор кардан', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: _linkStudent,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
            child: const Text('Пайваст кардан', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showStudentStats(int studentId, String studentName) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15102A),
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
                  return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
                }
                if (snapshot.hasError || snapshot.data?.statusCode != 200) {
                  return const Center(child: Text('Хатогӣ дар боркунии омор', style: TextStyle(color: Colors.white)));
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
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Омори пешрафти $studentName',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    // Quick stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Китобҳои дастрас',
                            '${stats['booksReadCount']}',
                            Icons.menu_book,
                            Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Холҳои миёна',
                            '${stats['averageScorePercentage']}%',
                            Icons.analytics,
                            Colors.deepPurpleAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Таърихи супоридани тестҳо',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (attempts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'То ҳол тестҳо супорида нашудаанд',
                            style: TextStyle(color: Colors.white.withOpacity(0.5)),
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
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    if (isGraded)
                                      Text(
                                        'Хол: ${a['score']}/${a['totalQuestions']}',
                                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                      )
                                    else
                                      Text(
                                        'Холҳои вариантӣ: ${a['optionEarnedPoints'] ?? a['earnedPoints']} аз ${a['optionTotalPoints'] ?? a['totalPoints']}',
                                        style: TextStyle(color: Colors.teal.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold),
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
                                    color: isPassed ? Colors.teal : Colors.redAccent,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
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
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    if (_isLoadingStudents) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
    }

    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'Ҳеҷ донишҷӯ пайваст карда нашудааст',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showLinkStudentDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Пайваст кардани донишҷӯ', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
            ),
          ],
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
          final List books = student['books'] ?? [];

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
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _pickAndUploadStudentAvatar(student['id']),
                            child: CircleAvatar(
                              backgroundColor: Colors.deepPurpleAccent.withOpacity(0.15),
                              backgroundImage: student['imageUrl'] != null && student['imageUrl'].toString().isNotEmpty
                                  ? NetworkImage(_getFullImageUrl(student['imageUrl'].toString()))
                                  : null,
                              child: student['imageUrl'] != null && student['imageUrl'].toString().isNotEmpty
                                  ? null
                                  : Text(
                                      _getInitials(student['name']),
                                      style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name'],
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                student['email'],
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
                    ],
                  ),
                  const Divider(height: 32, thickness: 1),
                  Text(
                    'Китобҳои дастрасшуда (${books.length}):',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  books.isEmpty
                      ? Text('Ҳеҷ китоб дастрас нест.', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: books.map((b) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                b['title'],
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showLinkStudentDialog,
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showGradingBottomSheet(int attemptId) {
    final attemptFuture = ApiService.get('/api/tests/attempts/$attemptId');
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15102A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      builder: (ctx) {
        Map<int, int> tempGrades = {};
        Map<int, TextEditingController> controllers = {};
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollController) {
                return FutureBuilder(
                  future: attemptFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
                    }
                    if (snapshot.hasError || snapshot.data?.statusCode != 200) {
                      return const Center(child: Text('Хатогӣ дар боркунии маълумот', style: TextStyle(color: Colors.white)));
                    }

                    final attemptDetail = jsonDecode(snapshot.data!.body);
                    final answers = attemptDetail['answers'] as List;

                    // Initialize grading
                    answers.forEach((ans) {
                      if (ans['questionType'] == 'Closed' && !tempGrades.containsKey(ans['answerId'])) {
                        tempGrades[ans['answerId']] = ans['earnedPoints'] ?? 0;
                      }
                    });

                    void submitGrades() async {
                      setModalState(() {
                        isSubmitting = true;
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
                            const SnackBar(content: Text('Баҳодиҳӣ бомуваффақият захира шуд.'), backgroundColor: Colors.teal),
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
                          isSubmitting = false;
                        });
                      }
                    }

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
                          'Тафтиши кор: ${attemptDetail['studentName']}',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Тест: ${attemptDetail['testTitle']}',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
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
                              color: Colors.white.withOpacity(isClosed ? 0.05 : 0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(isClosed ? 0.1 : 0.04)),
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
                                        color: isClosed ? Colors.amber.withOpacity(0.1) : Colors.deepPurple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        ans['questionType'] == 'TrueFalse'
                                            ? 'Рост/Дурӯғ'
                                            : (isClosed ? 'Саволи Хаттӣ' : 'Интихобӣ'),
                                        style: TextStyle(
                                          color: isClosed ? Colors.amber : Colors.deepPurpleAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (!isClosed)
                                      Text(
                                        'Балл: ${ans['earnedPoints']} / $maxPoints',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                      )
                                    else
                                      Row(
                                        children: [
                                          const Text('Балл: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                          SizedBox(
                                            width: 50,
                                            height: 30,
                                            child: TextField(
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                                              decoration: InputDecoration(
                                                contentPadding: EdgeInsets.zero,
                                                fillColor: Colors.black26,
                                                filled: true,
                                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                                                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                                              ),
                                              controller: controllers.putIfAbsent(
                                                answerId,
                                                () => TextEditingController(text: '${tempGrades[answerId] ?? 0}')
                                                  ..selection = TextSelection.fromPosition(TextPosition(offset: '${tempGrades[answerId] ?? 0}'.length)),
                                              ),
                                              onChanged: (val) {
                                                final points = int.tryParse(val) ?? 0;
                                                tempGrades[answerId] = points.clamp(0, maxPoints);
                                              },
                                            ),
                                          ),
                                          Text(' / $maxPoints', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  ans['questionText'],
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ҷавоби донишҷӯ:',
                                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
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
                                                  final fileUrl = studentAnswer.startsWith('http') 
                                                      ? studentAnswer 
                                                      : '${ApiService.baseUrl}$studentAnswer';
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
                                                icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white),
                                                label: const Text('Кушодани файл', style: TextStyle(color: Colors.white)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.teal,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                              ),
                                            ),
                                          );
                                        } else {
                                          return Text(
                                            studentAnswer.isNotEmpty ? studentAnswer : 'Ҷавоб дода нашудааст',
                                            style: TextStyle(
                                              color: isClosed ? Colors.amberAccent : Colors.white,
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
                        if (isSubmitting)
                          const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
                        else
                          ElevatedButton(
                            onPressed: submitGrades,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Тасдиқи баҳоҳо ва фиристодан', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGradingList() {
    if (_isLoadingAttempts) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
    }

    if (_pendingAttempts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.teal.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'Ҳамаи тестҳо тафтиш шудаанд!',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
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
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      attempt['studentEmail'],
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      attempt['testTitle'],
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _showGradingBottomSheet(attempt['attemptId']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Тафтиш', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTestsList() {
    if (_isLoadingTests) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _tests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'Ҳеҷ тест сохта нашудааст',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tests.length,
              itemBuilder: (context, index) {
                final test = _tests[index];
                final List questions = test['questions'] ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      test['title'] ?? '',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${questions.length} савол • ${test['description'] ?? "Имтиҳон"}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                    ),
                    trailing: const Icon(Icons.quiz, color: Colors.deepPurpleAccent),
                  ),
                );
              },
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
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15102A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teacherName,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Панели назорати муаллим',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.deepPurpleAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.4),
          tabs: [
            const Tab(text: 'Донишҷӯён'),
            const Tab(text: 'Тестҳо'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Тафтиш'),
                  if (_pendingAttempts.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '${_pendingAttempts.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            const Tab(text: 'Паёмҳо'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStudentsList(),
          _buildTestsList(),
          _buildGradingList(),
          const NotificationsFeedScreen(),
        ],
      ),
    );
  }
}
