import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'ai_tutor_screen.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<dynamic> recommendations;
  final Map<String, dynamic>? studyTimeAllocation;
  final String? portfolioFeedback;
  final String? whatIfScenario;
  final String? peerGroupRecommendationText;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.recommendations = const [],
    this.studyTimeAllocation,
    this.portfolioFeedback,
    this.whatIfScenario,
    this.peerGroupRecommendationText,
  });
}

class SpecialtiesScreen extends StatefulWidget {
  static final ValueNotifier<int> activeTabNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<List<dynamic>> selectedSavedSpecialtiesNotifier = ValueNotifier<List<dynamic>>([]);

  const SpecialtiesScreen({super.key});

  static String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  static pw.Widget _buildPdfHeaderCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
      ),
    );
  }

  static pw.Widget _buildPdfDataCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9),
        textAlign: align,
      ),
    );
  }

  static Future<void> _generateAndPrintPdfStatic(BuildContext context, List<dynamic> items) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final nowStr = _formatDateTime(DateTime.now());
    final countStr = '${items.length} аз 12';
    final clusterId = items.isNotEmpty ? (items.first['clusterId']?.toString() ?? '5') : '5';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'РӮЙХАТИ ИХТИСОСҲОИ ИНТИХОБШУДА',
                  style: pw.TextStyle(font: fontBold, fontSize: 18),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Гурӯҳ: $clusterId', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                  pw.Text('Сана: $nowStr', style: pw.TextStyle(font: fontRegular, fontSize: 11)),
                  pw.Text('Шумора: $countStr', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                columnWidths: const {
                  0: pw.FixedColumnWidth(25),
                  1: pw.FixedColumnWidth(40),
                  2: pw.FixedColumnWidth(160),
                  3: pw.FixedColumnWidth(220),
                  4: pw.FixedColumnWidth(60),
                  5: pw.FixedColumnWidth(60),
                  6: pw.FixedColumnWidth(35),
                  7: pw.FixedColumnWidth(45),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildPdfHeaderCell('№', fontBold),
                      _buildPdfHeaderCell('ID', fontBold),
                      _buildPdfHeaderCell('Ихтисос', fontBold),
                      _buildPdfHeaderCell('Муассиса', fontBold),
                      _buildPdfHeaderCell('Шакл', fontBold),
                      _buildPdfHeaderCell('Намуд', fontBold),
                      _buildPdfHeaderCell('Зина', fontBold),
                      _buildPdfHeaderCell('Нақша', fontBold),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final item = entry.value;
                    final id = item['id']?.toString() ?? '';
                    final specCode = item['specialtyCode']?.toString() ?? '';
                    final specName = item['specialtyName']?.toString() ?? '';
                    final univName = item['universityName']?.toString() ?? '';
                    final studyForm = item['studyForm']?.toString() ?? 'рӯзона';
                    final studyType = item['studyType']?.toString() ?? '';
                    final planSeats = item['planSeats']?.toString() ?? '0';

                    return pw.TableRow(
                      children: [
                        _buildPdfDataCell(idx.toString(), fontRegular),
                        _buildPdfDataCell(id, fontRegular),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: '$specCode - ',
                                  style: pw.TextStyle(font: fontBold, fontSize: 9),
                                ),
                                pw.TextSpan(
                                  text: specName,
                                  style: pw.TextStyle(font: fontRegular, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildPdfDataCell(univName, fontRegular),
                        _buildPdfDataCell(studyForm, fontRegular),
                        _buildPdfDataCell(studyType, fontRegular),
                        _buildPdfDataCell('11', fontRegular),
                        _buildPdfDataCell(planSeats, fontBold, align: pw.TextAlign.center),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Довталаб: _______________________________________', style: pw.TextStyle(font: fontRegular, fontSize: 11)),
                  pw.Text('Санаи чоп: $nowStr', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'ruixati_ihtisosho_${DateTime.now().millisecondsSinceEpoch}.pdf';

    String savedPath = '';
    bool savedSuccessfully = false;

    // Try saving directly to standard Download folder (Android)
    try {
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final file = File('${downloadDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          savedPath = file.path;
          savedSuccessfully = true;
        }
      }
    } catch (_) {}

    // Fallback 1: external storage directory (Android)
    if (!savedSuccessfully && Platform.isAndroid) {
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final file = File('${extDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          savedPath = file.path;
          savedSuccessfully = true;
        }
      } catch (_) {}
    }

    // Fallback 2: documents directory (iOS/Android/Desktop)
    if (!savedSuccessfully) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final file = File('${docDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        savedPath = file.path;
        savedSuccessfully = true;
      } catch (_) {}
    }

    if (savedSuccessfully && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Файл бомуваффақият боргирӣ шуд:\n$savedPath'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } else {
      throw Exception('Нӯсхабардории файл ноком шуд.');
    }
  }

  static Future<void> printSelectedSpecialties(BuildContext context) async {
    final list = selectedSavedSpecialtiesNotifier.value;
    if (list.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF22873B)),
      ),
    );

    try {
      await _generateAndPrintPdfStatic(context, list);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Хатогии боргирӣ: $e')),
        );
      }
    } finally {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  State<SpecialtiesScreen> createState() => _SpecialtiesScreenState();
}

class _SpecialtiesScreenState extends State<SpecialtiesScreen> {
  int _selectedClusterId = 5; // Default to Cluster 5 (Medical)
  List<dynamic> _specialties = [];
  List<dynamic> _universities = [];
  bool _isLoadingSpecialties = true;
  bool _isLoadingUniversities = true;
  String? _selectedUniversityCode;
  String _searchQuery = '';
  String? _selectedStudyType; // null = all, 'ройгон' = free/budget, 'пулакӣ' = contract
  String? _selectedStudyForm; // null = all, 'рӯзона', 'ғоибона', 'фосилавӣ'
  String? _selectedStudyLanguage; // null = all, 'тоҷикӣ', 'русӣ', 'тоҷикӣ, русӣ'
  double? _minScore;
  double? _maxScore;
  int? _minTuitionFee;
  int? _maxTuitionFee;
  int? _minSeats;
  int? _maxSeats;
  String? _sortBy;
  String? _specialtyName;
  String? _specialtyCode;

  final TextEditingController _minScoreController = TextEditingController();
  final TextEditingController _maxScoreController = TextEditingController();
  final TextEditingController _minFeeController = TextEditingController();
  final TextEditingController _maxFeeController = TextEditingController();
  final TextEditingController _minSeatsController = TextEditingController();
  final TextEditingController _maxSeatsController = TextEditingController();
  final TextEditingController _specNameController = TextEditingController();
  final TextEditingController _specCodeController = TextEditingController();

  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadMore = false;

  int _activeTab = 0; // 0 = Browse, 1 = AI recommender, 2 = Saved Bookmarks
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _aiPromptController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  
  Timer? _debounce;
  
  final List<ChatMessage> _chatMessages = [];
  bool _isLoadingAi = false;

  double? _selectedMinPercent;
  String? _selectedCity;
  String? _selectedDirection;
  String? _selectedInstitutionType;

  List<dynamic> _savedSpecialties = [];
  bool _isLoadingSaved = true;

  bool _isSyncing = false;

  Future<void> _syncSpecialties() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await ApiService.post('/api/Ntc/sync?clusterId=$_selectedClusterId', {});
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Маълумоти ихтисосҳо бо муваффақият навсозӣ шуд!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _fetchUniversities();
        await _fetchSpecialties(reset: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Хатогӣ ҳангоми навсозӣ'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Хатогии пайвастшавӣ ба сервер'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Widget _buildSyncButton(bool isDarkMode) {
    return _isSyncing
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF22873B)),
          )
        : IconButton(
            icon: const Icon(Icons.sync, color: Color(0xFF22873B)),
            tooltip: 'Навсозии ихтисосҳо',
            onPressed: _syncSpecialties,
          );
  }

  void _onActiveTabChanged() {
    if (mounted) {
      setState(() {
        _activeTab = SpecialtiesScreen.activeTabNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    SpecialtiesScreen.activeTabNotifier.removeListener(_onActiveTabChanged);
    _debounce?.cancel();
    _minScoreController.dispose();
    _maxScoreController.dispose();
    _minFeeController.dispose();
    _maxFeeController.dispose();
    _minSeatsController.dispose();
    _maxSeatsController.dispose();
    _specNameController.dispose();
    _specCodeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    SpecialtiesScreen.activeTabNotifier.addListener(_onActiveTabChanged);
    _fetchUniversities();
    _fetchSpecialties(reset: true);
    _fetchSavedSpecialties();
    
    // Add default friendly welcome message from Teacher Advisor
    _chatMessages.add(ChatMessage(
      text: 'Салом довталаби азиз! Ман Муаллими роҳнамои интеллектуалӣ ҳастам. Ба ман бигӯед, ки ба кадом ихтисосҳо дӯстдорӣ доред, дар кадом шаҳр таҳсил кардан мехоҳед ва ё бали худро нависед. Ман омори тестҳои шуморо таҳлил карда, ихтисоси мувофиқ ва роҳҳои беҳтар кардани натиҷаҳоро ба мисли муаллими воқеӣ мефаҳмонам.',
      isUser: false,
    ));
  }

  Future<void> _fetchUniversities() async {
    try {
      final response = await ApiService.get('/api/Ntc/universities?clusterId=$_selectedClusterId');
      if (response.statusCode == 200) {
        setState(() {
          _universities = jsonDecode(response.body) as List<dynamic>;
          _isLoadingUniversities = false;
        });
      } else {
        setState(() {
          _isLoadingUniversities = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingUniversities = false;
      });
    }
  }

  Future<void> _fetchSpecialties({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _isLoadingSpecialties = true;
        _specialties.clear();
      });
    } else {
      setState(() {
        _isLoadMore = true;
      });
    }

    try {
      String endpoint = '/api/Ntc/specialties?clusterId=$_selectedClusterId&page=$_currentPage&pageSize=25';
      if (_selectedUniversityCode != null && _selectedUniversityCode!.isNotEmpty) {
        endpoint += '&universityCode=$_selectedUniversityCode';
      }
      if (_searchQuery.isNotEmpty) {
        endpoint += '&search=${Uri.encodeComponent(_searchQuery)}';
      }
      if (_specialtyName != null && _specialtyName!.isNotEmpty) {
        endpoint += '&specialtyName=${Uri.encodeComponent(_specialtyName!)}';
      }
      if (_specialtyCode != null && _specialtyCode!.isNotEmpty) {
        endpoint += '&specialtyCode=${Uri.encodeComponent(_specialtyCode!)}';
      }
      if (_selectedStudyType != null) {
        endpoint += '&studyType=${Uri.encodeComponent(_selectedStudyType!)}';
      }
      if (_selectedStudyForm != null) {
        endpoint += '&studyForm=${Uri.encodeComponent(_selectedStudyForm!)}';
      }
      if (_selectedStudyLanguage != null) {
        endpoint += '&studyLanguage=${Uri.encodeComponent(_selectedStudyLanguage!)}';
      }
      if (_minScore != null) {
        endpoint += '&minScore=$_minScore';
      }
      if (_maxScore != null) {
        endpoint += '&maxScore=$_maxScore';
      }
      if (_minTuitionFee != null) {
        endpoint += '&minFee=$_minTuitionFee';
      }
      if (_maxTuitionFee != null) {
        endpoint += '&maxFee=$_maxTuitionFee';
      }
      if (_minSeats != null) {
        endpoint += '&minSeats=$_minSeats';
      }
      if (_maxSeats != null) {
        endpoint += '&maxSeats=$_maxSeats';
      }
      if (_sortBy != null) {
        endpoint += '&sortBy=$_sortBy';
      }

      final response = await ApiService.get(endpoint);
      if (response.statusCode == 200) {
        final resBody = jsonDecode(response.body);
        final items = resBody['items'] as List<dynamic>;
        setState(() {
          if (reset) {
            _specialties = items;
          } else {
            _specialties.addAll(items);
          }
          _totalPages = resBody['totalPages'] as int;
          _isLoadingSpecialties = false;
          _isLoadMore = false;
        });
      } else {
        setState(() {
          _isLoadingSpecialties = false;
          _isLoadMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingSpecialties = false;
        _isLoadMore = false;
      });
    }
  }

  Future<void> _fetchSavedSpecialties() async {
    setState(() {
      _isLoadingSaved = true;
    });
    try {
      final response = await ApiService.get('/api/Ntc/saved-specialties');
      if (response.statusCode == 200) {
        setState(() {
          final rawList = jsonDecode(response.body) as List<dynamic>;
          // Sort descending by lastYearPassingScore (null treated as 0)
          rawList.sort((a, b) {
            final scoreA = (a['lastYearPassingScore'] as num?)?.toDouble() ?? 0.0;
            final scoreB = (b['lastYearPassingScore'] as num?)?.toDouble() ?? 0.0;
            return scoreB.compareTo(scoreA);
          });
          _savedSpecialties = rawList;
          _isLoadingSaved = false;
        });
      } else {
        setState(() {
          _isLoadingSaved = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingSaved = false;
      });
    }
  }

  Future<void> _saveSpecialty(Map<String, dynamic> specialty) async {
    try {
      final response = await ApiService.post('/api/Ntc/save-specialty', specialty);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ихтисос ба заметкаҳо илова карда шуд.')),
        );
        _fetchSavedSpecialties();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хатогӣ ҳангоми илова кардан.')),
      );
    }
  }

  Future<void> _deleteSavedSpecialty(dynamic specialty) async {
    try {
      final code = specialty['specialtyCode'];
      final univ = Uri.encodeComponent(specialty['universityName'] ?? '');
      final form = Uri.encodeComponent(specialty['studyForm'] ?? '');
      final type = Uri.encodeComponent(specialty['studyType'] ?? '');
      final response = await ApiService.delete('/api/Ntc/saved-specialty/$code?universityName=$univ&studyForm=$form&studyType=$type');
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ихтисос аз заметкаҳо нест карда шуд.')),
        );
        
        // Synchronize selected Saved Specialties list
        final list = List<dynamic>.from(SpecialtiesScreen.selectedSavedSpecialtiesNotifier.value);
        list.removeWhere((x) =>
          x['specialtyCode'] == specialty['specialtyCode'] &&
          x['universityName'] == specialty['universityName'] &&
          x['studyForm'] == specialty['studyForm'] &&
          x['studyType'] == specialty['studyType']
        );
        SpecialtiesScreen.selectedSavedSpecialtiesNotifier.value = list;

        _fetchSavedSpecialties();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хатогӣ ҳангоми нест кардан.')),
      );
    }
  }

  Future<void> _askAiRecommend({
    String? customPrompt,
    double? minPercent,
    String? city,
    String? direction,
    String? institutionType,
  }) async {
    final query = customPrompt ?? _aiPromptController.text.trim();
    if (query.isEmpty && minPercent == null && city == null && direction == null && institutionType == null) return;

    if (customPrompt == null) {
      _aiPromptController.clear();
    }

    setState(() {
      _chatMessages.add(ChatMessage(text: query.isNotEmpty ? query : 'Филтри навбатӣ', isUser: true));
      _isLoadingAi = true;
    });

    _scrollToBottom();

    try {
      final response = await ApiService.post('/api/Ntc/ai-recommend', {
        'prompt': query.isNotEmpty ? query : 'Интихоби ихтисос',
        if (minPercent != null) 'minPercent': minPercent,
        if (city != null) 'city': city,
        if (direction != null) 'direction': direction,
        if (institutionType != null) 'institutionType': institutionType,
      });
      if (response.statusCode == 200) {
        final resBody = jsonDecode(response.body);
        final respText = resBody['responseText'] as String?;
        final recs = resBody['recommendations'] as List<dynamic>? ?? [];
        final studyAlloc = resBody['studyTimeAllocation'] as Map<String, dynamic>?;
        final portfolioFeed = resBody['portfolioFeedback'] as String?;
        final whatIf = resBody['whatIfScenario'] as String?;
        final peerGroup = resBody['peerGroupRecommendationText'] as String?;

        setState(() {
          _chatMessages.add(ChatMessage(
            text: respText ?? '',
            isUser: false,
            recommendations: recs,
            studyTimeAllocation: studyAlloc,
            portfolioFeedback: portfolioFeed,
            whatIfScenario: whatIf,
            peerGroupRecommendationText: peerGroup,
          ));
          _isLoadingAi = false;
        });
      } else {
        setState(() {
          _chatMessages.add(ChatMessage(
            text: 'Бухшиш, дар пайвастшавӣ хатогӣ рух дод. Лутфан, дертар кӯшиш кунед.',
            isUser: false,
          ));
          _isLoadingAi = false;
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages.add(ChatMessage(
          text: 'Алоқа бо сервер дастнорас аст. Пайвастшавии худро санҷед.',
          isUser: false,
        ));
        _isLoadingAi = false;
      });
    }

    _scrollToBottom();
  }

  void _togglePercentFilter(double percent) {
    setState(() {
      if (_selectedMinPercent == percent) {
        _selectedMinPercent = null;
      } else {
        _selectedMinPercent = percent;
      }
    });
    _applyFiltersAndQuery();
  }

  void _toggleCityFilter(String city) {
    setState(() {
      if (_selectedCity == city) {
        _selectedCity = null;
      } else {
        _selectedCity = city;
      }
    });
    _applyFiltersAndQuery();
  }

  void _toggleDirectionFilter(String dir) {
    setState(() {
      if (_selectedDirection == dir) {
        _selectedDirection = null;
      } else {
        _selectedDirection = dir;
      }
    });
    _applyFiltersAndQuery();
  }

  void _toggleInstitutionTypeFilter(String type) {
    setState(() {
      if (_selectedInstitutionType == type) {
        _selectedInstitutionType = null;
      } else {
        _selectedInstitutionType = type;
      }
    });
    _applyFiltersAndQuery();
  }

  void _applyFiltersAndQuery() {
    String filterPrompt = 'Анализи нав дар асоси филтрҳо:';
    if (_selectedMinPercent != null) {
      filterPrompt += ' Шонс ${_selectedMinPercent!.toInt()}%+,';
    }
    if (_selectedCity != null) {
      filterPrompt += ' Шаҳри $_selectedCity,';
    }
    if (_selectedDirection != null) {
      filterPrompt += ' Равияи $_selectedDirection,';
    }
    if (_selectedInstitutionType != null) {
      filterPrompt += ' Муассисаи ${_selectedInstitutionType == 'university' ? 'Донишгоҳӣ' : 'Коллеҷӣ'},';
    }
    if (filterPrompt.endsWith(',')) {
      filterPrompt = filterPrompt.substring(0, filterPrompt.length - 1);
    }

    _askAiRecommend(
      customPrompt: filterPrompt,
      minPercent: _selectedMinPercent,
      city: _selectedCity,
      direction: _selectedDirection,
      institutionType: _selectedInstitutionType,
    );
  }

  Widget _buildFilterGroupLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, left: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildAiFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : (color.computeLuminance() > 0.5 ? Colors.black87 : Colors.black54),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedColor: color,
        backgroundColor: color.withOpacity(0.12),
        onSelected: (_) => onSelected(),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }


  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.isEmpty) {
      _fetchSpecialties(reset: true);
    } else {
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _fetchSpecialties(reset: true);
      });
    }
  }

  bool _isSpecialtySaved(dynamic spec) {
    return _savedSpecialties.any((s) =>
        s['specialtyCode'] == spec['specialtyCode'] &&
        s['universityName'] == spec['universityName'] &&
        s['studyForm'] == spec['studyForm'] &&
        s['studyType'] == spec['studyType']);
  }

  Map<String, dynamic> _toMap(dynamic specialty) {
    return {
      'id': specialty['id'] ?? 0,
      'clusterId': specialty['clusterId'] ?? 5,
      'clusterName': specialty['clusterName'] ?? '',
      'universityCode': specialty['universityCode'] ?? '',
      'universityName': specialty['universityName'] ?? '',
      'specialtyCode': specialty['specialtyCode'] ?? '',
      'specialtyName': specialty['specialtyName'] ?? '',
      'studyForm': specialty['studyForm'] ?? '',
      'studyType': specialty['studyType'] ?? '',
      'tuitionFee': specialty['tuitionFee'],
      'studyLanguage': specialty['studyLanguage'] ?? '',
      'planSeats': specialty['planSeats'] ?? 0,
      'lastYearPassingScore': specialty['lastYearPassingScore']
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final user = Provider.of<AuthProvider>(context).currentUser;
    final isAdmin = user?.role == 'Admin';
    final theme = Theme.of(context);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final primaryColor = const Color(0xFF22873B);
    final cardColor = isDarkMode ? Colors.white.withOpacity(0.04) : Colors.white;
    final backgroundColor = isDarkMode ? Colors.black : const Color(0xFFF1F8F4);

    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AiTutorScreen()),
          );
        },
        backgroundColor: primaryColor,
        icon: const Icon(Icons.school, color: Colors.white, size: 20),
        label: const Text('Мураббӣ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main Body Stack
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: [
                  _buildBrowseView(textColor, isDarkMode, cardColor, primaryColor, isAdmin),
                  _buildAiView(textColor, isDarkMode, cardColor, primaryColor),
                  _buildSavedView(textColor, isDarkMode, cardColor, primaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, bool isDarkMode) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = index;
          });
          if (index == 2) {
            _fetchSavedSpecialties();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF22873B) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrowseView(Color textColor, bool isDarkMode, Color cardColor, Color primaryColor, bool isAdmin) {
    return Column(
      children: [
        // Search & Filters bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDarkMode ? Colors.white12 : const Color(0xFFD1E2D5),
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  if (isAdmin) ...[
                    _buildSyncButton(isDarkMode),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ҷустуҷӯ аз рӯи ихтисос ё донишгоҳ...',
                        hintStyle: TextStyle(color: textColor.withOpacity(0.4), fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: textColor.withOpacity(0.4), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDarkMode ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F8F4),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _showAdvancedFiltersBottomSheet,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: _hasActiveAdvancedFilters()
                                ? const Color(0xFF22873B)
                                : (isDarkMode ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F8F4)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.tune,
                            color: _hasActiveAdvancedFilters()
                                ? Colors.white
                                : textColor.withOpacity(0.6),
                            size: 20,
                          ),
                        ),
                        if (_activeFiltersCount() > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Center(
                                child: Text(
                                  '${_activeFiltersCount()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _isLoadingSpecialties
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : _specialties.isEmpty
                  ? _buildEmptyState(textColor)
                  : NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification scrollInfo) {
                        if (!_isLoadMore &&
                            _currentPage < _totalPages &&
                            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                          _currentPage++;
                          _fetchSpecialties(reset: false);
                          return true;
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _buildSpecialtiesTable(_specialties, textColor, isDarkMode, primaryColor, false),
                            ),
                            if (_isLoadMore)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(color: primaryColor),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildAiView(Color textColor, bool isDarkMode, Color cardColor, Color primaryColor) {
    return Column(
      children: [
        // Chat History List
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _chatMessages.length + (_isLoadingAi ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _chatMessages.length) {
                // Return a beautiful typing/thinking indicator
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16, right: 64),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                        topLeft: Radius.circular(16),
                      ),
                      border: Border.all(
                        color: isDarkMode ? Colors.white10 : const Color(0xFFD1E2D5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Муаллим фикр мекунад...',
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final msg = _chatMessages[index];
              final lastAiIndex = _chatMessages.lastIndexWhere((m) => !m.isUser);
              final isLatestAi = lastAiIndex == index;
              return _buildChatMessageItem(
                msg,
                textColor,
                isDarkMode,
                cardColor,
                primaryColor,
                showDashboard: isLatestAi,
              );
            },
          ),
        ),

        // Dynamic Quick Filtering & Diagnosis Chips
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF151515) : const Color(0xFFF3F8F5),
            border: Border(
              top: BorderSide(
                color: isDarkMode ? Colors.white12 : const Color(0xFFD1E2D5),
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                // 1. Chance filter
                _buildFilterGroupLabel('Шонси қабул:'),
                _buildAiFilterChip(
                  label: '90%+ (Сабук)',
                  isSelected: _selectedMinPercent == 90,
                  color: Colors.green,
                  onSelected: () => _togglePercentFilter(90),
                ),
                _buildAiFilterChip(
                  label: '75%+ (Мақсад)',
                  isSelected: _selectedMinPercent == 75,
                  color: Colors.orange,
                  onSelected: () => _togglePercentFilter(75),
                ),
                _buildAiFilterChip(
                  label: '50%+ (Таваккал)',
                  isSelected: _selectedMinPercent == 50,
                  color: Colors.deepOrange,
                  onSelected: () => _togglePercentFilter(50),
                ),
                _buildAiFilterChip(
                  label: '30%+ (Орзу)',
                  isSelected: _selectedMinPercent == 30,
                  color: Colors.purple,
                  onSelected: () => _togglePercentFilter(30),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 20, color: isDarkMode ? Colors.white24 : Colors.grey.withOpacity(0.3)),
                const SizedBox(width: 8),

                // 2. City Filter
                _buildFilterGroupLabel('Шаҳр:'),
                ...['Душанбе', 'Хуҷанд', 'Кӯлоб', 'Бохтар', 'Данғара'].map((city) {
                  return _buildAiFilterChip(
                    label: city,
                    isSelected: _selectedCity == city,
                    color: Colors.blue,
                    onSelected: () => _toggleCityFilter(city),
                  );
                }),
                const SizedBox(width: 8),
                Container(width: 1, height: 20, color: isDarkMode ? Colors.white24 : Colors.grey.withOpacity(0.3)),
                const SizedBox(width: 8),

                // 3. Direction Filter
                _buildFilterGroupLabel('Равия:'),
                ...['Дандонпизишк', 'Ҷарроҳӣ', 'Дорусозӣ', 'Педиатр'].map((dir) {
                  return _buildAiFilterChip(
                    label: dir,
                    isSelected: _selectedDirection == dir,
                    color: Colors.teal,
                    onSelected: () => _toggleDirectionFilter(dir),
                  );
                }),
                const SizedBox(width: 8),
                Container(width: 1, height: 20, color: isDarkMode ? Colors.white24 : Colors.grey.withOpacity(0.3)),
                const SizedBox(width: 8),

                // 4. Institution Type Filter
                _buildFilterGroupLabel('Навъ:'),
                _buildAiFilterChip(
                  label: 'Донишгоҳ',
                  isSelected: _selectedInstitutionType == 'university',
                  color: Colors.indigo,
                  onSelected: () => _toggleInstitutionTypeFilter('university'),
                ),
                _buildAiFilterChip(
                  label: 'Коллеҷ',
                  isSelected: _selectedInstitutionType == 'college',
                  color: Colors.cyan,
                  onSelected: () => _toggleInstitutionTypeFilter('college'),
                ),
              ],
            ),
          ),
        ),

        // Bottom Chat Input Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDarkMode ? Colors.white12 : const Color(0xFFD1E2D5),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _aiPromptController,
                  style: TextStyle(color: textColor, fontSize: 13),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _askAiRecommend(),
                  decoration: InputDecoration(
                    hintText: 'Савол диҳед: "кадом ихтисос барои ман хуб аст?"',
                    hintStyle: TextStyle(color: textColor.withOpacity(0.4), fontSize: 13),
                    filled: true,
                    fillColor: isDarkMode ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F8F4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isLoadingAi ? null : _askAiRecommend,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isLoadingAi ? Colors.grey : const Color(0xFF22873B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatMessageItem(
    ChatMessage msg,
    Color textColor,
    bool isDarkMode,
    Color cardColor,
    Color primaryColor, {
    required bool showDashboard,
  }) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF22873B),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      );
    } else {
      // AI response (Teacher Advisor)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teacher Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF22873B).withOpacity(0.2)),
                ),
                child: const Icon(
                  Icons.school,
                  color: Color(0xFF22873B),
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Муаллими роҳнамо (AI)',
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Response text bubble
          Container(
            margin: const EdgeInsets.only(bottom: 16, right: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                topLeft: Radius.circular(16),
              ),
              border: Border.all(
                color: isDarkMode ? Colors.white10 : const Color(0xFFD1E2D5),
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
            ),
          ),

          if (showDashboard)
            _buildAiAnalyticsDashboard(msg, isDarkMode, textColor, primaryColor),

          // Render Inline specialty cards if recommended
          if (msg.recommendations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Ихтисосҳои тавсияшуда:',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...msg.recommendations.map((rec) {
              final spec = rec['specialty'];
              final matchType = rec['matchType'];
              final feedback = rec['feedback'];
              final pointsShort75 = rec['pointsShortTo75'];
              final pointsShort90 = rec['pointsShortTo90'];
              final acceptanceChance = rec['acceptanceChance'];
              final laborMarket = rec['laborMarket'];

              Color badgeColor;
              String badgeText;
              if (matchType == 'Safe') {
                badgeColor = Colors.green;
                badgeText = 'Шонси баланд';
              } else if (matchType == 'Target') {
                badgeColor = Colors.orange;
                badgeText = 'Бо кӯшиши бештар';
              } else {
                badgeColor = Colors.red;
                badgeText = 'Кӯшиши хеле зиёд';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 14, right: 16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withOpacity(0.04) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: badgeColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isSpecialtySaved(spec) ? Icons.bookmark : Icons.bookmark_border,
                              color: _isSpecialtySaved(spec) ? const Color(0xFF22873B) : textColor.withOpacity(0.4),
                              size: 18,
                            ),
                            onPressed: () {
                              if (_isSpecialtySaved(spec)) {
                                _deleteSavedSpecialty(spec);
                              } else {
                                _saveSpecialty(_toMap(spec));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${spec['specialtyCode']} - ${spec['specialtyName']}',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            spec['universityName'] ?? '',
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildCardInfoChip(
                                Icons.payments_outlined,
                                spec['tuitionFee'] != null ? '${spec['tuitionFee']} сомонӣ' : 'Ройгон',
                                spec['tuitionFee'] != null ? Colors.amber : Colors.green,
                                isDarkMode,
                              ),
                              const SizedBox(width: 8),
                              _buildCardInfoChip(
                                Icons.emoji_events_outlined,
                                spec['lastYearPassingScore'] != null && spec['lastYearPassingScore'] > 0
                                    ? '${spec['lastYearPassingScore']} бал'
                                    : 'Бал: озод',
                                Colors.blue,
                                isDarkMode,
                              ),
                            ],
                          ),
                          if (laborMarket != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildCardInfoChip(
                                  Icons.work_outline,
                                  'Талаб: ${laborMarket['demand']}',
                                  Colors.purple,
                                  isDarkMode,
                                ),
                                const SizedBox(width: 8),
                                _buildCardInfoChip(
                                  Icons.trending_up,
                                  'Маош: ${laborMarket['avgSalary']}',
                                  Colors.indigo,
                                  isDarkMode,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              feedback,
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (pointsShort75 != null && pointsShort75 > 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Барои шонси 75% дохил шудан ба шумо боз $pointsShort75 хол намерасад.',
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
          ],
        ],
      );
    }
  }


  Widget _buildSavedView(Color textColor, bool isDarkMode, Color cardColor, Color primaryColor) {
    if (_isLoadingSaved) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_savedSpecialties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline, size: 64, color: textColor.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              'Заметкаҳо холӣ мебошанд',
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ихтисосҳоро аз қисмати ҷустуҷӯ ё AI ба заметкаҳо илова кунед',
              style: TextStyle(
                color: textColor.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _buildSpecialtiesTable(_savedSpecialties, textColor, isDarkMode, primaryColor, true),
      ),
    );
  }

  Widget _buildSpecialtyCard(dynamic item, Color textColor, Color cardColor, bool isDarkMode, bool isSavedView) {
    final specName = item['specialtyName']?.toString() ?? '';
    final specCode = item['specialtyCode']?.toString() ?? '';
    final univName = item['universityName']?.toString() ?? '';
    final studyForm = item['studyForm']?.toString() ?? 'рӯзона';
    final studyType = item['studyType']?.toString() ?? '';
    final tuitionFee = (item['tuitionFee'] as num?)?.toInt();
    final studyLanguage = item['studyLanguage']?.toString() ?? 'тоҷикӣ';
    final planSeats = (item['planSeats'] as num?)?.toInt() ?? 0;
    final lastYearScore = (item['lastYearPassingScore'] as num?)?.toDouble();

    final isFree = studyType.toLowerCase().contains('ройгон') || studyType.toLowerCase().contains('буҷет');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFF22873B).withOpacity(0.15),
          width: 1,
        ),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upper section with badges
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.02) : const Color(0xFFF1F8F4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isFree ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isFree ? const Color(0xFFA5D6A7) : const Color(0xFFFFCC80),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isFree ? 'Ройгон (Буҷет)' : 'Пулакӣ (Шартнома)',
                          style: TextStyle(
                            color: isFree ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          studyForm.toUpperCase(),
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    isSavedView ? Icons.delete_outline : (_isSpecialtySaved(item) ? Icons.bookmark : Icons.bookmark_border),
                    color: isSavedView ? Colors.red : (_isSpecialtySaved(item) ? const Color(0xFF22873B) : textColor.withOpacity(0.4)),
                    size: 22,
                  ),
                  onPressed: () {
                    if (isSavedView) {
                      _deleteSavedSpecialty(item);
                    } else {
                      if (_isSpecialtySaved(item)) {
                        _deleteSavedSpecialty(item);
                      } else {
                        _saveSpecialty(_toMap(item));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Specialty Code & Language
                Row(
                  children: [
                    Text(
                      'Рамз: $specCode',
                      style: const TextStyle(
                        color: Color(0xFF22873B),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '•',
                      style: TextStyle(color: textColor.withOpacity(0.3)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Забони таҳсил: $studyLanguage',
                      style: TextStyle(
                        color: textColor.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Specialty Name
                Text(
                  specName,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                
                // University Name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.account_balance,
                      color: textColor.withOpacity(0.4),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        univName,
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Key-value Grid (Clean rows)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withOpacity(0.02) : const Color(0xFFF9FBF9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Plan Seats (Шумораи қабул)
                      _buildInfoRow(
                        Icons.people_alt_outlined,
                        'Шумораи қабул (Нақша):',
                        '$planSeats нафар',
                        textColor,
                      ),
                      const Divider(height: 16, thickness: 0.5),
                      // Tuition Fee / Contract Price
                      _buildInfoRow(
                        Icons.payments_outlined,
                        'Маблағи таҳсил (Пул):',
                        isFree ? 'Ройгон' : (tuitionFee != null ? '$tuitionFee сомонӣ' : 'Шартнома'),
                        isFree ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                      ),
                      const Divider(height: 16, thickness: 0.5),
                      // Last Year's Passing Score
                      _buildInfoRow(
                        Icons.trending_up,
                        'Бали гузариши соли гузашта:',
                        (lastYearScore != null && lastYearScore > 0) ? '$lastYearScore бал' : 'Муайян нашуда',
                        (lastYearScore != null && lastYearScore > 0) ? const Color(0xFF22873B) : textColor.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color valueColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _toggleSavedSelection(dynamic item, bool? checked) {
    final list = List<dynamic>.from(SpecialtiesScreen.selectedSavedSpecialtiesNotifier.value);
    final isChecked = list.any((x) =>
      x['specialtyCode'] == item['specialtyCode'] &&
      x['universityName'] == item['universityName'] &&
      x['studyForm'] == item['studyForm'] &&
      x['studyType'] == item['studyType']
    );

    if (checked == true) {
      if (list.length >= 12) {
        _showMaxLimitWarningDialog();
        return;
      }
      if (!isChecked) {
        list.add(item);
      }
    } else {
      list.removeWhere((x) =>
        x['specialtyCode'] == item['specialtyCode'] &&
        x['universityName'] == item['universityName'] &&
        x['studyForm'] == item['studyForm'] &&
        x['studyType'] == item['studyType']
      );
    }
    SpecialtiesScreen.selectedSavedSpecialtiesNotifier.value = list;
  }

  void _showMaxLimitWarningDialog() {
    Timer? autoDismissTimer;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        autoDismissTimer = Timer(const Duration(seconds: 4), () {
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Диққат!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        autoDismissTimer?.cancel();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      autoDismissTimer?.cancel();
    });
  }

  Widget _buildSpecialtiesTable(List<dynamic> items, Color textColor, bool isDarkMode, Color primaryColor, bool isSavedView) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        border: Border.all(color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
        child: DataTable(
          columnSpacing: 14,
          horizontalMargin: 10,
          headingRowHeight: 48,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 52,
          headingRowColor: MaterialStateProperty.all(isDarkMode ? const Color(0xFF1B5E20).withOpacity(0.3) : const Color(0xFFE8F5E9)),
          border: TableBorder.all(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
            width: 1,
          ),
          columns: [
            DataColumn(label: Text('ID', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            if (isSavedView)
              const DataColumn(label: Text('Интихоб', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('Рамзи ихтисос', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('Гурӯҳи ихтисосҳо', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('Муассисаи таълимӣ', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('Номи ихтисос', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('Шакли таҳсил', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('Намуди таҳсил', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('Маблағи таҳсил', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('Забони таҳсил', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('Нақша', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('Зинаи таҳсил', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('Бали гузариш', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('Амал', style: TextStyle(color: isDarkMode ? Colors.green.shade200 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11))),
          ],
          rows: items.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final item = entry.value;

            final id = item['id']?.toString() ?? '';
            final specName = item['specialtyName']?.toString() ?? '';
            final specCode = item['specialtyCode']?.toString() ?? '';
            final univName = item['universityName']?.toString() ?? '';
            final studyForm = item['studyForm']?.toString() ?? 'рӯзона';
            final studyType = item['studyType']?.toString() ?? '';
            final tuitionFee = (item['tuitionFee'] as num?)?.toInt();
            final studyLanguage = item['studyLanguage']?.toString() ?? 'тоҷикӣ';
            final planSeats = (item['planSeats'] as num?)?.toInt() ?? 0;
            final lastYearScore = (item['lastYearPassingScore'] as num?)?.toDouble();
            final clusterName = item['clusterName']?.toString() ?? '';

            final isFree = studyType.toLowerCase().contains('ройгон') || studyType.toLowerCase().contains('буҷет');

            return DataRow(
              cells: [
                DataCell(Text(id.isNotEmpty ? id : idx.toString(), style: TextStyle(color: textColor, fontSize: 11))),
                if (isSavedView)
                  DataCell(
                    ValueListenableBuilder<List<dynamic>>(
                      valueListenable: SpecialtiesScreen.selectedSavedSpecialtiesNotifier,
                      builder: (context, selectedList, _) {
                        final isChecked = selectedList.any((x) => 
                          x['specialtyCode'] == item['specialtyCode'] &&
                          x['universityName'] == item['universityName'] &&
                          x['studyForm'] == item['studyForm'] &&
                          x['studyType'] == item['studyType']
                        );
                        return Checkbox(
                          value: isChecked,
                          activeColor: const Color(0xFF22873B),
                          onChanged: (bool? checked) {
                            _toggleSavedSelection(item, checked);
                          },
                        );
                      },
                    ),
                  ),
                DataCell(Text(specCode, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold))),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      clusterName,
                      style: TextStyle(color: textColor, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      univName,
                      style: TextStyle(color: textColor, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      specName,
                      style: TextStyle(color: textColor, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),                DataCell(Text(studyForm, style: TextStyle(color: textColor, fontSize: 11))),
                DataCell(Text(studyType, style: TextStyle(color: textColor, fontSize: 11))),
                DataCell(
                  Text(
                    isFree ? 'ройгон' : (tuitionFee != null ? '$tuitionFee' : 'шартнома'),
                    style: TextStyle(
                      color: isFree ? Colors.green : Colors.orange.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(Text(studyLanguage, style: TextStyle(color: textColor, fontSize: 11))),
                DataCell(Text('$planSeats', style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold))),
                DataCell(Text('11', style: TextStyle(color: textColor, fontSize: 11))),
                DataCell(
                  Text(
                    (lastYearScore != null && lastYearScore > 0) ? '$lastYearScore' : '—',
                    style: TextStyle(
                      color: (lastYearScore != null && lastYearScore > 0) ? Colors.green.shade700 : textColor.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      isSavedView ? Icons.delete_outline : (_isSpecialtySaved(item) ? Icons.bookmark : Icons.bookmark_border),
                      color: isSavedView ? Colors.red : (_isSpecialtySaved(item) ? const Color(0xFF22873B) : textColor.withOpacity(0.4)),
                      size: 16,
                    ),
                    onPressed: () {
                      if (isSavedView) {
                        _deleteSavedSpecialty(item);
                      } else {
                        if (_isSpecialtySaved(item)) {
                          _deleteSavedSpecialty(item);
                        } else {
                          _saveSpecialty(_toMap(item));
                        }
                      }
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }



  Widget _buildAiAnalyticsDashboard(ChatMessage msg, bool isDarkMode, Color textColor, Color primaryColor) {
    if (msg.studyTimeAllocation == null && msg.portfolioFeedback == null && msg.whatIfScenario == null && msg.peerGroupRecommendationText == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.03) : const Color(0xFFF1F8F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFD1E2D5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Таҳлил ва Тавсияҳои AI',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Study time allocation progress bars
          if (msg.studyTimeAllocation != null && msg.studyTimeAllocation!.isNotEmpty) ...[
            Text(
              'Тақсимоти вақти омӯзиш (таъсири маржиналӣ):',
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...msg.studyTimeAllocation!.entries.map((entry) {
              final subject = entry.key;
              final double val = (entry.value as num).toDouble();
              Color barColor;
              if (subject.contains("Химия")) barColor = Colors.teal;
              else if (subject.contains("Биология")) barColor = Colors.green;
              else if (subject.contains("Физика")) barColor = Colors.orange;
              else barColor = Colors.blue;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          subject,
                          style: TextStyle(color: textColor, fontSize: 11),
                        ),
                        Text(
                          '${val.toStringAsFixed(0)}%',
                          style: TextStyle(color: barColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: val / 100.0,
                        backgroundColor: isDarkMode ? Colors.white10 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 8),
          ],

          // 2. What-If simulator scenario card
          if (msg.whatIfScenario != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.help_outline, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      msg.whatIfScenario!,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // 3. Portfolio feedback card
          if (msg.portfolioFeedback != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      msg.portfolioFeedback!,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // 4. Peer recommendations
          if (msg.peerGroupRecommendationText != null && msg.peerGroupRecommendationText!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.group_outlined, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      msg.peerGroupRecommendationText!,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardInfoChip(IconData icon, String label, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  int _activeFiltersCount() {
    int count = 0;
    if (_selectedClusterId != 5) count++;
    if (_selectedUniversityCode != null && _selectedUniversityCode!.isNotEmpty) count++;
    if (_selectedStudyType != null) count++;
    if (_selectedStudyForm != null) count++;
    if (_selectedStudyLanguage != null) count++;
    if (_minScore != null) count++;
    if (_maxScore != null) count++;
    if (_minTuitionFee != null) count++;
    if (_maxTuitionFee != null) count++;
    if (_minSeats != null) count++;
    if (_maxSeats != null) count++;
    if (_specialtyName != null && _specialtyName!.isNotEmpty) count++;
    if (_specialtyCode != null && _specialtyCode!.isNotEmpty) count++;
    return count;
  }

  bool _hasActiveAdvancedFilters() {
    return _activeFiltersCount() > 0;
  }

  Widget _buildFilterInputs(Color textColor, bool isDarkMode, StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cluster dropdown
        Text(
          'Интихоби кластер',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: textColor.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _selectedClusterId,
              dropdownColor: isDarkMode ? Colors.black : Colors.white,
              style: TextStyle(color: textColor, fontSize: 13),
              icon: Icon(Icons.arrow_drop_down, color: textColor.withOpacity(0.6)),
              items: const [
                DropdownMenuItem<int>(
                  value: 0,
                  child: Text('Ҳамаи кластерҳо', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                DropdownMenuItem<int>(
                  value: 1,
                  child: Text('Кластери 1 — Табиӣ ва техникӣ'),
                ),
                DropdownMenuItem<int>(
                  value: 2,
                  child: Text('Кластери 2 — Иқтисод ва география'),
                ),
                DropdownMenuItem<int>(
                  value: 3,
                  child: Text('Кластери 3 — Филология, педагогика ва санъат'),
                ),
                DropdownMenuItem<int>(
                  value: 4,
                  child: Text('Кластери 4 — Ҷомеашиносӣ ва ҳуқуқ'),
                ),
                DropdownMenuItem<int>(
                  value: 5,
                  child: Text('Кластери 5 — Тиб, биология ва варзиш'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setModalState(() {
                    _selectedClusterId = val;
                    _selectedUniversityCode = null;
                  });
                  _fetchUniversities();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        // University dropdown
        Text(
          'Муассисаи таълимӣ',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _isLoadingUniversities
            ? const SizedBox(
                height: 44,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: textColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedUniversityCode,
                    hint: Text(
                      'Ҳамаи муассисаҳои таълимӣ',
                      style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13),
                    ),
                    dropdownColor: isDarkMode ? Colors.black : Colors.white,
                    style: TextStyle(color: textColor, fontSize: 13),
                    icon: Icon(Icons.arrow_drop_down, color: textColor.withOpacity(0.6)),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'Ҳамаи муассисаҳо',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ..._universities.map((u) {
                        return DropdownMenuItem<String>(
                          value: u['code']?.toString(),
                          child: Text(
                            u['name']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        _selectedUniversityCode = val;
                      });
                    },
                  ),
                ),
              ),
        const SizedBox(height: 20),

        // Study Type / Shakhli tahsil (Ҳама, Ройгон, Пулакӣ)
        Text(
          'Намуди таҳсил',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: textColor.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedStudyType,
              hint: Text(
                'Ҳамаи намудҳо',
                style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13),
              ),
              dropdownColor: isDarkMode ? Colors.black : Colors.white,
              style: TextStyle(color: textColor, fontSize: 13),
              icon: Icon(Icons.arrow_drop_down, color: textColor.withOpacity(0.6)),
              items: const [
                DropdownMenuItem<String>(value: null, child: Text('Ҳамаи намудҳо', style: TextStyle(fontWeight: FontWeight.bold))),
                DropdownMenuItem<String>(value: 'ройгон', child: Text('Ройгон')),
                DropdownMenuItem<String>(value: 'пулакӣ', child: Text('Пулакӣ')),
              ],
              onChanged: (val) {
                setModalState(() {
                  _selectedStudyType = val;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Study Form / Shakli tahsil (Рӯзона, Ғоибона, Фосилавӣ)
        Text(
          'Шакли таҳсил',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: textColor.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedStudyForm,
              hint: Text(
                'Ҳамаи шаклҳо',
                style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13),
              ),
              dropdownColor: isDarkMode ? Colors.black : Colors.white,
              style: TextStyle(color: textColor, fontSize: 13),
              icon: Icon(Icons.arrow_drop_down, color: textColor.withOpacity(0.6)),
              items: const [
                DropdownMenuItem<String>(value: null, child: Text('Ҳамаи шаклҳо', style: TextStyle(fontWeight: FontWeight.bold))),
                DropdownMenuItem<String>(value: 'рӯзона', child: Text('Рӯзона')),
                DropdownMenuItem<String>(value: 'ғоибона', child: Text('Ғоибона')),
                DropdownMenuItem<String>(value: 'фосилавӣ', child: Text('Фосилавӣ')),
              ],
              onChanged: (val) {
                setModalState(() {
                  _selectedStudyForm = val;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Забони таҳсил',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: textColor.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedStudyLanguage,
              hint: Text(
                'Ҳамаи забонҳо',
                style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13),
              ),
              dropdownColor: isDarkMode ? Colors.black : Colors.white,
              style: TextStyle(color: textColor, fontSize: 13),
              icon: Icon(Icons.arrow_drop_down, color: textColor.withOpacity(0.6)),
              items: const [
                DropdownMenuItem<String>(value: null, child: Text('Ҳамаи забонҳо', style: TextStyle(fontWeight: FontWeight.bold))),
                DropdownMenuItem<String>(value: 'тоҷикӣ', child: Text('Тоҷикӣ (алоҳида)')),
                DropdownMenuItem<String>(value: 'русӣ', child: Text('Русӣ (алоҳида)')),
                DropdownMenuItem<String>(value: 'тоҷикӣ, русӣ', child: Text('Тоҷикӣ ва русӣ (якҷоя)')),
              ],
              onChanged: (val) {
                setModalState(() {
                  _selectedStudyLanguage = val;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Номи ихтисос',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _specNameController,
          decoration: InputDecoration(
            hintText: 'Масалан: Муҳандис',
            hintStyle: TextStyle(color: textColor.withOpacity(0.3), fontSize: 13),
            prefixIcon: Icon(Icons.school_outlined, color: textColor.withOpacity(0.4), size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: TextStyle(color: textColor, fontSize: 13),
          onChanged: (val) {
            _specialtyName = val;
          },
        ),
        const SizedBox(height: 20),

        Text(
          'Рамзи ихтисос (ID)',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _specCodeController,
          decoration: InputDecoration(
            hintText: 'Масалан: 1-250103',
            hintStyle: TextStyle(color: textColor.withOpacity(0.3), fontSize: 13),
            prefixIcon: Icon(Icons.pin_outlined, color: textColor.withOpacity(0.4), size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: TextStyle(color: textColor, fontSize: 13),
          onChanged: (val) {
            _specialtyCode = val;
          },
        ),
        const SizedBox(height: 20),

        Text(
          'Бали гузариш',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Бал аз',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                  hintText: 'Масалан: 100',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.3), fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(color: textColor, fontSize: 13),
                controller: _minScoreController,
                onChanged: (val) {
                  _minScore = double.tryParse(val);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Бал то',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                  hintText: 'Масалан: 350',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.3), fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(color: textColor, fontSize: 13),
                controller: _maxScoreController,
                onChanged: (val) {
                  _maxScore = double.tryParse(val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Text(
          'Маблағи таҳсил (Пул)',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Маблағ аз',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                  hintText: 'Масалан: 3000',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.3), fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(color: textColor, fontSize: 13),
                controller: _minFeeController,
                onChanged: (val) {
                  _minTuitionFee = int.tryParse(val);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Маблағ то',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                  hintText: 'Масалан: 10000',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.3), fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(color: textColor, fontSize: 13),
                controller: _maxFeeController,
                onChanged: (val) {
                  _maxTuitionFee = int.tryParse(val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Text(
          'Шумораи қабул (нақша)',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Ҷойҳо аз',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                  hintText: 'Масалан: 5',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.3), fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(color: textColor, fontSize: 13),
                controller: _minSeatsController,
                onChanged: (val) {
                  _minSeats = int.tryParse(val);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Ҷойҳо то',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                  hintText: 'Масалан: 50',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.3), fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(color: textColor, fontSize: 13),
                controller: _maxSeatsController,
                onChanged: (val) {
                  _maxSeats = int.tryParse(val);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAdvancedFiltersBottomSheet() {
    _minScoreController.text = _minScore?.toString() ?? '';
    _maxScoreController.text = _maxScore?.toString() ?? '';
    _minFeeController.text = _minTuitionFee?.toString() ?? '';
    _maxFeeController.text = _maxTuitionFee?.toString() ?? '';
    _minSeatsController.text = _minSeats?.toString() ?? '';
    _maxSeatsController.text = _maxSeats?.toString() ?? '';
    _specNameController.text = _specialtyName ?? '';
    _specCodeController.text = _specialtyCode ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
        final textColor = isDarkMode ? Colors.white : Colors.black;
        final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final double screenHeight = MediaQuery.of(context).size.height;
            final bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
            return Container(
              height: isPortrait ? screenHeight * 0.9 : null,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: isPortrait ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.close, color: textColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text(
                        'Филтрҳо',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          setModalState(() {
                            _minScore = null;
                            _maxScore = null;
                            _minTuitionFee = null;
                            _maxTuitionFee = null;
                            _minSeats = null;
                            _maxSeats = null;
                            _sortBy = null;
                            _specialtyName = null;
                            _specialtyCode = null;
                            _selectedClusterId = 5;
                            _selectedUniversityCode = null;
                            _selectedStudyType = null;
                            _selectedStudyForm = null;
                            _selectedStudyLanguage = null;
                            _minScoreController.clear();
                            _maxScoreController.clear();
                            _minFeeController.clear();
                            _maxFeeController.clear();
                            _minSeatsController.clear();
                            _maxSeatsController.clear();
                            _specNameController.clear();
                            _specCodeController.clear();
                          });
                        },
                        child: const Text(
                          'Тоза кардан',
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  
                  isPortrait
                      ? Expanded(
                          child: SingleChildScrollView(
                            child: _buildFilterInputs(textColor, isDarkMode, setModalState),
                          ),
                        )
                      : Flexible(
                          child: SingleChildScrollView(
                            child: _buildFilterInputs(textColor, isDarkMode, setModalState),
                          ),
                        ),
                  
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22873B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        _minScore = double.tryParse(_minScoreController.text);
                        _maxScore = double.tryParse(_maxScoreController.text);
                        _minTuitionFee = int.tryParse(_minFeeController.text);
                        _maxTuitionFee = int.tryParse(_maxFeeController.text);
                        _minSeats = int.tryParse(_minSeatsController.text);
                        _maxSeats = int.tryParse(_maxSeatsController.text);
                        _specialtyName = _specNameController.text.isNotEmpty ? _specNameController.text : null;
                        _specialtyCode = _specCodeController.text.isNotEmpty ? _specCodeController.text : null;

                        Navigator.pop(context);
                        _fetchSpecialties(reset: true);
                      },
                      child: const Center(
                        child: Text(
                          'Филтр кардан',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalChip(String label, String? value, String? groupValue, ValueChanged<String?> onChanged, bool isDarkMode) {
    final isSelected = groupValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF22873B)
              : (isDarkMode ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F8F4)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF22873B)
                : (isDarkMode ? Colors.white10 : const Color(0xFFD1E2D5)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 64, color: textColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Ихтисосҳо ёфт нашуданд',
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Лутфан параметрҳои филтрро иваз кунед',
            style: TextStyle(
              color: textColor.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, String? groupValue, ValueChanged<String?> onChanged) {
    final isSelected = groupValue == value;
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onChanged(value),
      backgroundColor: isDarkMode ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F8F4),
      selectedColor: const Color(0xFF22873B),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDarkMode ? Colors.white70 : Colors.black87),
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
