import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class CreateTestScreen extends StatefulWidget {
  const CreateTestScreen({super.key});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final List<Map<String, dynamic>> _questions = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addQuestion(); // Start with one empty question template
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
      final response = await ApiService.post('/api/tests', payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Тест бомуваффақият сохта шуд.'), backgroundColor: Colors.teal),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        title: const Text('Сохтани тести нав', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF15102A),
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
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Маълумоти умумӣ',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Номи тест',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Масалан: Имтиҳони ниҳоӣ аз Математика',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Номи тестро ворид кунед' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Тавсифи тест (ихтиёрӣ)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Тавсифи кӯтоҳи имтиҳон...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          backgroundColor: Colors.deepPurpleAccent.withOpacity(0.15),
                          side: BorderSide.none,
                          label: Text(
                            'Саволи ${index + 1}',
                            style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 12),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Матни савол',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      initialValue: q['questionText'],
                      onChanged: (val) => q['questionText'] = val,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            dropdownColor: const Color(0xFF15102A),
                            value: qType,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Намуди савол',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.black26,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Single', child: Text('Интихобӣ (Якҷавоба)')),
                              DropdownMenuItem(value: 'Multiple', child: Text('Интихобӣ (Мултиҷавоб)')),
                              DropdownMenuItem(value: 'Closed', child: Text('Хаттӣ (Пӯшида)')),
                              DropdownMenuItem(value: 'TrueFalse', child: Text('Рост / Дурӯғ (Тест)')),
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
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Балл',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.black26,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            initialValue: '${q['points']}',
                            onChanged: (val) {
                              q['points'] = int.tryParse(val) ?? 10;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Сурати савол (URL-и сурат, ихтиёрӣ)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Масалан: https://example.com/image.png',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      initialValue: q['imageUrl'] ?? '',
                      onChanged: (val) => q['imageUrl'] = val,
                    ),

                    if (isClosed) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Рамз / Ҷавоби дуруст (ихтиёрӣ)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: 'Калима ё рамзи махсус барои санҷиши автоматӣ',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        initialValue: q['correctOption'] ?? '',
                        onChanged: (val) => q['correctOption'] = val,
                      ),
                    ],

                    if (!isClosed && !isTrueFalse) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Вариантҳои ҷавоб:',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Options A, B, C, D Inputs
                      _buildOptionField('A', q, index),
                      _buildOptionField('B', q, index),
                      _buildOptionField('C', q, index),
                      _buildOptionField('D', q, index),
                    ],

                    if (!isClosed) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Ҷавоби дуруст:',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      // Correct Options Selection
                      if (isTrueFalse)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ChoiceChip(
                              label: const Text('Рост'),
                              selected: q['correctOption'] == 'A',
                              selectedColor: Colors.deepPurpleAccent,
                              backgroundColor: Colors.black26,
                              labelStyle: TextStyle(color: q['correctOption'] == 'A' ? Colors.white : Colors.white60),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    q['correctOption'] = 'A';
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Дурӯғ'),
                              selected: q['correctOption'] == 'B',
                              selectedColor: Colors.deepPurpleAccent,
                              backgroundColor: Colors.black26,
                              labelStyle: TextStyle(color: q['correctOption'] == 'B' ? Colors.white : Colors.white60),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    q['correctOption'] = 'B';
                                  });
                                }
                              },
                            ),
                          ],
                        )
                      else if (qType == 'Single')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: ['A', 'B', 'C', 'D'].map((opt) {
                            final bool active = q['correctOption'] == opt;
                            return ChoiceChip(
                              label: Text('Варианти $opt'),
                              selected: active,
                              selectedColor: Colors.deepPurpleAccent,
                              backgroundColor: Colors.black26,
                              labelStyle: TextStyle(color: active ? Colors.white : Colors.white60),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    q['correctOption'] = opt;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: ['A', 'B', 'C', 'D'].map((opt) {
                            final String correctStr = q['correctOption'] ?? '';
                            final List<String> list = correctStr.split(',').map((o) => o.trim()).toList();
                            final bool active = list.contains(opt);
                            return FilterChip(
                              label: Text('Варианти $opt'),
                              selected: active,
                              selectedColor: Colors.deepPurpleAccent,
                              backgroundColor: Colors.black26,
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(color: active ? Colors.white : Colors.white60),
                              onSelected: (_) => _toggleMultiCorrectOption(index, opt),
                            );
                          }).toList(),
                        ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),
            if (_isSaving)
              const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
            else
              ElevatedButton(
                onPressed: _saveTest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          prefixText: 'Варианти $label:  ',
          prefixStyle: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold),
          filled: true,
          fillColor: Colors.black12,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        initialValue: q['option$label'],
        onChanged: (val) => q['option$label'] = val,
      ),
    );
  }
}
