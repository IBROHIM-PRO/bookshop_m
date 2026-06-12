import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/theme_provider.dart';
import 'test_quiz.dart';

class NmtVariantScreen extends StatefulWidget {
  final int testId;
  final String testTitle;

  const NmtVariantScreen({super.key, required this.testId, required this.testTitle});

  @override
  State<NmtVariantScreen> createState() => _NmtVariantScreenState();
}

class _NmtVariantScreenState extends State<NmtVariantScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _nmtInfo;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fetchNmtInfo();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchNmtInfo() async {
    try {
      final response = await ApiService.get('/api/tests/${widget.testId}/nmt-info');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _nmtInfo = data;
            _isLoading = false;
          });
          _animController.forward();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startQuiz(int? variant) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TestQuizScreen(
          testId: widget.testId,
          testTitle: widget.testTitle,
          variant: variant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? const Color(0xFF0D0D0D) : const Color(0xFFF5F7F5);
    final cardColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final accentColor = isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF1E7431);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Интихоби вариант',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _nmtInfo == null
              ? Center(
                  child: Text(
                    'Маълумот ёфт нашуд',
                    style: TextStyle(color: textColor.withOpacity(0.6)),
                  ),
                )
              : _buildContent(textColor, cardColor, accentColor, isDarkMode),
    );
  }

  Widget _buildContent(Color textColor, Color cardColor, Color accentColor, bool isDarkMode) {
    final info = _nmtInfo!;
    final variantCount = info['variantCount'] as int? ?? 1;
    final subject = info['subject'] as String? ?? 'Дигар';
    final questionsPerVariant = info['questionsPerVariant'] as int? ?? 25;
    final singleCount = info['singleCount'] as int? ?? 20;
    final multipleCount = info['multipleCount'] as int? ?? 4;
    final closedCount = info['closedCount'] as int? ?? 2;
    final totalQuestions = info['totalQuestions'] as int? ?? 0;
    final hasImages = info['hasImages'] as bool? ?? false;

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 600 ? 5 : (screenWidth > 350 ? 3 : 2);
    final double childAspectRatio = screenWidth > 600 ? 1.4 : 1.15;

    return FadeTransition(
      opacity: _animController,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Test info card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFD1E2D5),
                ),
                boxShadow: isDarkMode ? [] : [
                  BoxShadow(
                    color: const Color(0xFF228B22).withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.school_rounded, color: accentColor, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.testTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subject,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatChip(Icons.quiz_outlined, '$questionsPerVariant', 'савол', textColor, isDarkMode),
                      _buildStatChip(Icons.layers_outlined, '$variantCount', 'вариант', textColor, isDarkMode),
                      _buildStatChip(Icons.storage_outlined, '$totalQuestions', 'ҳамагӣ', textColor, isDarkMode),
                    ],
                  ),
                  if (hasImages) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined, color: accentColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Саволҳо бо расм мавҷуданд',
                          style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Divider(color: textColor.withOpacity(0.08)),
                  const SizedBox(height: 12),
                  // Question type breakdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTypeInfo('Ягона', singleCount, textColor, isDarkMode),
                      _buildTypeInfo('Мувофиқат', multipleCount, textColor, isDarkMode),
                      if (closedCount > 0)
                        _buildTypeInfo('Кушода', closedCount, textColor, isDarkMode),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Random variant button
            _buildVariantButton(
              icon: Icons.shuffle_rounded,
              title: 'Тасодуфӣ',
              subtitle: 'Саволҳо аз ҳамаи вариантҳо тасодуфӣ интихоб мешаванд',
              isSpecial: true,
              onTap: () => _startQuiz(null),
              textColor: textColor,
              cardColor: cardColor,
              accentColor: accentColor,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 16),

            // Section title
            Text(
              'Вариантро интихоб кунед',
              style: TextStyle(
                color: textColor.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Variant grid
             GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: variantCount,
              itemBuilder: (context, index) {
                final variantNum = index + 1;
                return _buildVariantGridItem(
                  variantNum,
                  textColor,
                  cardColor,
                  accentColor,
                  isDarkMode,
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color textColor, bool isDarkMode) {
    return Column(
      children: [
        Icon(icon, color: textColor.withOpacity(0.5), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeInfo(String label, int count, Color textColor, bool isDarkMode) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildVariantButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSpecial,
    required VoidCallback onTap,
    required Color textColor,
    required Color cardColor,
    required Color accentColor,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSpecial
              ? LinearGradient(
                  colors: isDarkMode
                      ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                      : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSpecial ? null : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isSpecial ? null : Border.all(color: textColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: isSpecial
                  ? const Color(0xFF228B22).withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSpecial ? Colors.white.withOpacity(0.2) : accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: isSpecial ? Colors.white : accentColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSpecial ? Colors.white : textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSpecial ? Colors.white.withOpacity(0.7) : textColor.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isSpecial ? Colors.white.withOpacity(0.6) : textColor.withOpacity(0.3),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantGridItem(
    int variantNum,
    Color textColor,
    Color cardColor,
    Color accentColor,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: () => _startQuiz(variantNum),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFD1E2D5),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '$variantNum',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Вариант $variantNum',
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
