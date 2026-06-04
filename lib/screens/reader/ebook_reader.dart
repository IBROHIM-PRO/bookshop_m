import 'package:flutter/material.dart';
import '../../models/book.dart';

class EbookReaderScreen extends StatefulWidget {
  final Book book;

  const EbookReaderScreen({super.key, required this.book});

  @override
  State<EbookReaderScreen> createState() => _EbookReaderScreenState();
}

class _EbookReaderScreenState extends State<EbookReaderScreen> {
  double _fontSize = 18.0;
  bool _isDarkMode = true;
  double _scrollProgress = 0.0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    if (maxScroll <= 0) return;
    setState(() {
      _scrollProgress = (currentScroll / maxScroll).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF0F0C20) : const Color(0xFFF9F6EE);
    final textColor = _isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF1C1917);
    final appBarColor = _isDarkMode ? const Color(0xFF15102A) : const Color(0xFFE2E2D5);

    // Seed content or fallback
    final String contentText = widget.book.content ?? 
        "Барои ин китоб матн ворид карда нашудааст. Лутфан бо админ дар тамос шавед.";

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _isDarkMode ? Colors.white : Colors.black),
        title: Text(
          widget.book.title,
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Font Decrease
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () {
              setState(() {
                if (_fontSize > 12) _fontSize -= 2;
              });
            },
          ),
          // Font Increase
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                if (_fontSize < 36) _fontSize += 2;
              });
            },
          ),
          // Toggle Theme
          IconButton(
            icon: Icon(_isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round),
            onPressed: () {
              setState(() {
                _isDarkMode = !_isDarkMode;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Scroll Progress Bar
          LinearProgressIndicator(
            value: _scrollProgress,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
            minHeight: 4,
          ),
          
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title / Header in Reader
                  Text(
                    widget.book.title,
                    style: TextStyle(
                      fontSize: _fontSize + 6,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.book.author,
                    style: TextStyle(
                      fontSize: _fontSize - 2,
                      color: textColor.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Divider(height: 32, thickness: 1),
                  const SizedBox(height: 8),
                  // Reading text
                  Text(
                    contentText,
                    style: TextStyle(
                      fontSize: _fontSize,
                      color: textColor,
                      height: 1.8,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Center(
                    child: Text(
                      'Ин охири китоб аст.',
                      style: TextStyle(
                        color: textColor.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
