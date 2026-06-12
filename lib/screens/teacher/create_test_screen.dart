import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';

class CreateTestScreen extends StatefulWidget {
  final int? testId;
  const CreateTestScreen({super.key, this.testId});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final List<Map<String, dynamic>> _questions = [];
  bool _isSaving = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.testId != null) {
      _loadTestDetails();
    } else {
      _addQuestion(); // Start with one empty question template
    }
  }

  Future<void> _loadTestDetails() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await ApiService.get('/api/tests/${widget.testId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        final qList = data['questions'] as List? ?? [];
        setState(() {
          _questions.clear();
          for (var q in qList) {
            _questions.add({
              'id': q['id'],
              'questionText': q['questionText'] ?? '',
              'questionType': q['questionType'] ?? 'Single',
              'points': q['points'] ?? 10,
              'optionA': q['optionA'] ?? '',
              'optionB': q['optionB'] ?? '',
              'optionC': q['optionC'] ?? '',
              'optionD': q['optionD'] ?? '',
              'correctOption': q['correctOption'] ?? 'A',
              'imageUrl': q['imageUrl'] ?? '',
            });
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Хатогӣ дар боркунии маълумоти тест')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хатогӣ дар пайвастшавӣ ба сервер')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, {String? hint, bool isDarkMode = true}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF6B7280), fontSize: 14),
      hintText: hint,
      hintStyle: TextStyle(color: isDarkMode ? const Color(0xFF788C7D) : const Color(0xFF9CA3AF), fontSize: 13),
      filled: true,
      fillColor: isDarkMode ? const Color(0xFF1A241D) : const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDarkMode ? const Color(0xFF2E3D32) : const Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDarkMode ? const Color(0xFF2E3D32) : const Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E7431), width: 1.5),
      ),
    );
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'questionText': '',
        'questionType': 'Single', // Single, Multiple, Closed
        'points': 10,
        'optionA': '',
        'optionB': '',
        'optionC': '',
        'optionD': '',
        'correctOption': 'A', // For multiple choice, comma-separated e.g. "A,B"
        'imageUrl': '',
      });
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length > 1) {
      setState(() {
        _questions.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тест бояд ҳадди аққал 1 савол дошта бошад')),
      );
    }
  }

  void _toggleMultiCorrectOption(int qIndex, String option) {
    setState(() {
      final q = _questions[qIndex];
      String current = q['correctOption'] ?? '';
      List<String> list = current.split(',').map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
      
      if (list.contains(option)) {
        list.remove(option);
      } else {
        list.add(option);
      }
      
      q['correctOption'] = list.join(',');
    });
  }

  Future<void> _saveTest() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate that questions are filled properly
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q['questionText'].toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Лутфан матни саволи ${i + 1}-ро пур кунед')),
        );
        return;
      }
      if (q['questionType'] != 'Closed' && q['questionType'] != 'TrueFalse') {
        if (q['optionA'].toString().trim().isEmpty ||
            q['optionB'].toString().trim().isEmpty ||
            q['optionC'].toString().trim().isEmpty ||
            q['optionD'].toString().trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Лутфан ҳамаи вариантҳоро барои саволи ${i + 1} ворид кунед')),
          );
          return;
        }
      }
      if (q['questionType'] != 'Closed') {
        if (q['correctOption'].toString().trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Лутфан ҷавоби дурустро барои саволи ${i + 1} интихоб кунед')),
          );
          return;
        }
      }
    }

    setState(() {
      _isSaving = true;
    });

    final payload = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'bookId': null,
      'questions': _questions.map((q) {
        final isClosed = q['questionType'] == 'Closed';
        final isTrueFalse = q['questionType'] == 'TrueFalse';
        return {
          'id': q['id'],
          'questionText': q['questionText'],
          'questionType': q['questionType'],
          'points': q['points'],
          'optionA': isClosed ? '' : (isTrueFalse ? 'Рост' : q['optionA']),
          'optionB': isClosed ? '' : (isTrueFalse ? 'Дурӯғ' : q['optionB']),
          'optionC': (isClosed || isTrueFalse) ? '' : q['optionC'],
          'optionD': (isClosed || isTrueFalse) ? '' : q['optionD'],
          'correctOption': q['correctOption'] ?? '',
          'imageUrl': q['imageUrl'] ?? '',
        };
      }).toList(),
    };

    try {
      final response = widget.testId != null
          ? await ApiService.put('/api/tests/${widget.testId}', payload)
          : await ApiService.post('/api/tests', payload);
          
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.testId != null ? 'Тест бомуваффақият таҳрир шуд.' : 'Тест бомуваффақият сохта шуд.'), 
            backgroundColor: Colors.teal
          ),
        );
        Navigator.of(context).pop(true); // Return success
      } else {
        final err = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['message'] ?? 'Хатогӣ ҳангоми захираи тест')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хатогӣ дар пайвастшавӣ ба сервер')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _uploadQuestionImage(Map<String, dynamic> q, String path, String name) async {
    try {
      setState(() {
        _isSaving = true;
      });
      
      final response = await ApiService.uploadFile(path, name);
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final fileUrl = resData['url'] as String?;
        if (fileUrl != null) {
          setState(() {
            q['imageUrl'] = fileUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Расм бомуваффақият боргузорӣ шуд!'), backgroundColor: Colors.teal),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Хатогӣ дар боргузории расм'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Хатогӣ: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showImageSourceBottomSheet(Map<String, dynamic> q, Color textColor, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF161E18) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: textColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Воридкунии расм',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Spacer to balance the close button
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Camera option
                _buildOptionRow(
                  context: context,
                  icon: Icons.camera_alt_outlined,
                  title: 'Камера',
                  textColor: textColor,
                  isDarkMode: isDarkMode,
                  onTap: () async {
                    Navigator.pop(context);
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.camera);
                    if (image != null) {
                      _uploadQuestionImage(q, image.path, image.name);
                    }
                  },
                ),
                Divider(
                  height: 1,
                  indent: 76,
                  color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
                ),

                // Documents option
                _buildOptionRow(
                  context: context,
                  icon: Icons.insert_drive_file_outlined,
                  title: 'Ҳуҷҷатҳо',
                  subtitle: 'Интихоби файлҳо',
                  textColor: textColor,
                  isDarkMode: isDarkMode,
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await FilePicker.pickFiles(type: FileType.image);
                    if (result != null && result.files.single.path != null) {
                      _uploadQuestionImage(q, result.files.single.path!, result.files.single.name);
                    }
                  },
                ),
                Divider(
                  height: 1,
                  indent: 76,
                  color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
                ),

                // Media option
                _buildOptionRow(
                  context: context,
                  icon: Icons.image_outlined,
                  title: 'Галерея',
                  subtitle: 'Интихоби расм ва видео',
                  textColor: textColor,
                  isDarkMode: isDarkMode,
                  onTap: () async {
                    Navigator.pop(context);
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      _uploadQuestionImage(q, image.path, image.name);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required Color textColor,
    required bool isDarkMode,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F8F4),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: textColor.withOpacity(0.5),
                fontSize: 13,
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isEditMode = widget.testId != null;

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
            isEditMode ? 'Таҳрири тест' : 'Сохтани тести нав',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E7431)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Таҳрири тест' : 'Сохтани тести нав', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          )
        ),
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Test Metadata info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Маълумоти умумӣ',
                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration('Номи тест', hint: 'Масалан: Имтиҳони ниҳоӣ аз Математика', isDarkMode: isDarkMode),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Номи тестро ворид кунед' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(color: textColor),
                    maxLines: 2,
                    decoration: _inputDecoration('Тавсифи тест (ихтиёрӣ)', hint: 'Тавсифи кӯтоҳи имтиҳон...', isDarkMode: isDarkMode),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Саволҳо (${_questions.length})',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add, color: Colors.deepPurpleAccent),
                  label: const Text('Саволи нав', style: TextStyle(color: Colors.deepPurpleAccent)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Questions List
            ...List.generate(_questions.length, (index) {
              final q = _questions[index];
              final String qType = q['questionType'];
              final bool isClosed = qType == 'Closed';
              final bool isTrueFalse = qType == 'TrueFalse';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          backgroundColor: const Color(0xFF1E7431).withOpacity(0.15),
                          side: BorderSide.none,
                          label: Text(
                            'Саволи ${index + 1}',
                            style: const TextStyle(color: Color(0xFF1E7431), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _removeQuestion(index),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      style: TextStyle(color: textColor),
                      decoration: _inputDecoration('Матни савол', isDarkMode: isDarkMode),
                      initialValue: q['questionText'],
                      onChanged: (val) => q['questionText'] = val,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            dropdownColor: cardBg,
                            value: qType,
                            style: TextStyle(color: textColor),
                            decoration: _inputDecoration('Намуди савол', isDarkMode: isDarkMode),
                            items: [
                              DropdownMenuItem(value: 'Single', child: Text('Интихобӣ (Якҷавоба)', style: TextStyle(color: textColor))),
                              DropdownMenuItem(value: 'Multiple', child: Text('Интихобӣ (Мултиҷавоб)', style: TextStyle(color: textColor))),
                              DropdownMenuItem(value: 'Closed', child: Text('Хаттӣ (Пӯшида)', style: TextStyle(color: textColor))),
                              DropdownMenuItem(value: 'TrueFalse', child: Text('Рост / Дурӯғ (Тест)', style: TextStyle(color: textColor))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  q['questionType'] = val;
                                  if (val == 'Closed') {
                                    q['points'] = 50;
                                    q['correctOption'] = '';
                                  } else if (val == 'Multiple') {
                                    q['points'] = 20;
                                    q['correctOption'] = 'A';
                                  } else if (val == 'TrueFalse') {
                                    q['points'] = 10;
                                    q['correctOption'] = 'A';
                                    q['optionA'] = 'Рост';
                                    q['optionB'] = 'Дурӯғ';
                                    q['optionC'] = '';
                                    q['optionD'] = '';
                                  } else {
                                    q['points'] = 10;
                                    q['correctOption'] = 'A';
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textColor),
                            decoration: _inputDecoration('Балл', isDarkMode: isDarkMode),
                            initialValue: '${q['points']}',
                            onChanged: (val) {
                              q['points'] = int.tryParse(val) ?? 10;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Image picker button
                    Row(
                      children: [
                        Text(
                          'Расми савол:',
                          style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showImageSourceBottomSheet(q, textColor, isDarkMode),
                          icon: const Icon(Icons.image, color: Colors.white, size: 18),
                          label: const Text('Боргузории расм', style: TextStyle(color: Colors.white, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E7431),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    if (q['imageUrl'] != null && q['imageUrl'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: ApiService.getFullImageUrl(q['imageUrl']),
                              height: 60,
                              width: 80,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const SizedBox(
                                width: 80,
                                height: 60,
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E7431))),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                q['imageUrl'] = '';
                              });
                            },
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                            label: const Text('Тоза кардан', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ],

                    if (isTrueFalse) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Ҷавоби дуруст:',
                        style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Radio<String>(
                            value: 'A',
                            groupValue: q['correctOption'],
                            activeColor: const Color(0xFF1E7431),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  q['correctOption'] = val;
                                });
                              }
                            },
                          ),
                          Text('Рост', style: TextStyle(color: textColor)),
                          const SizedBox(width: 20),
                          Radio<String>(
                            value: 'B',
                            groupValue: q['correctOption'],
                            activeColor: const Color(0xFF1E7431),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  q['correctOption'] = val;
                                });
                              }
                            },
                          ),
                          Text('Дурӯғ', style: TextStyle(color: textColor)),
                        ],
                      ),
                    ],

                    if (!isClosed && !isTrueFalse) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Вариантҳои ҷавоб (интихоб кунед ҷавоби дурустро аз чап):',
                        style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Options A, B, C, D Inputs with checkmarks on the left
                      _buildOptionField('A', q, index),
                      _buildOptionField('B', q, index),
                      _buildOptionField('C', q, index),
                      _buildOptionField('D', q, index),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),
            if (_isSaving)
              const Center(child: CircularProgressIndicator(color: Color(0xFF1E7431)))
            else
              ElevatedButton(
                onPressed: _saveTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E7431),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: const Text(
                  'Захира кардани тест',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionField(String label, Map<String, dynamic> q, int index) {
    final qType = q['questionType'] ?? 'Single';
    final isMultiple = qType == 'Multiple';
    final isSelected = isMultiple
        ? (q['correctOption'] ?? '').toString().split(',').map((o) => o.trim()).contains(label)
        : q['correctOption'] == label;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          if (isMultiple)
            Checkbox(
              value: isSelected,
              activeColor: const Color(0xFF1E7431),
              side: BorderSide(color: isDarkMode ? Colors.white54 : Colors.black54, width: 2),
              onChanged: (val) {
                _toggleMultiCorrectOption(index, label);
              },
            )
          else
            Radio<String>(
              value: label,
              groupValue: q['correctOption'],
              activeColor: const Color(0xFF1E7431),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    q['correctOption'] = val;
                  });
                }
              },
            ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              style: TextStyle(color: textColor),
              decoration: _inputDecoration('Варианти $label', isDarkMode: isDarkMode).copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              initialValue: q['option$label'],
              onChanged: (val) => q['option$label'] = val,
            ),
          ),
        ],
      ),
    );
  }
}
