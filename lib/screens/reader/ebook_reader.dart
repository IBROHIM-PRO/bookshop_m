import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';

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
  
  bool _isLoading = true;
  String? _error;
  String? _content;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadBookContent();
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

  Future<void> _loadBookContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/secure_ebook_${widget.book.id}.txt');

      if (await file.exists() && await file.length() > 0) {
        final content = await file.readAsString();
        if (mounted) {
          setState(() {
            _content = content;
            _isLoading = false;
          });
        }
        return;
      }

      // 1. Request access ticket from backend
      final ticketResponse = await ApiService.post(
        '/api/books/${widget.book.id}/request-ticket',
        {},
      );

      if (ticketResponse.statusCode == 200) {
        final ticketData = jsonDecode(ticketResponse.body);
        final ticket = ticketData['ticket'];

        // 2. Fetch content using the ticket
        final contentResponse = await ApiService.get(
          '/api/books/${widget.book.id}/content?ticket=$ticket',
        );

        if (contentResponse.statusCode == 200) {
          final contentData = jsonDecode(contentResponse.body);
          final contentText = contentData['content'];
          
          await file.writeAsString(contentText);

          if (mounted) {
            setState(() {
              _content = contentText;
              _isLoading = false;
            });
          }
          return;
        }
      }

      // If error occurs, extract the message
      String message = 'Дастрасӣ маҳдуд аст ё хатогӣ дар боркунии матн.';
      if (ticketResponse.body.isNotEmpty) {
        try {
          final errData = jsonDecode(ticketResponse.body);
          if (errData['message'] != null) {
            message = errData['message'];
          }
        } catch (_) {}
      }

      setState(() {
        _error = message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Хатогӣ дар пайвастшавӣ ба сервер.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF0F0C20) : const Color(0xFFF9F6EE);
    final textColor = _isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF1C1917);
    final appBarColor = _isDarkMode ? const Color(0xFF15102A) : const Color(0xFFE2E2D5);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
        ),
      );
    }

    final Widget bodyContent;

    if (_error != null) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadBookContent,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Боз кӯшиш кунед', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final String contentText = _content ?? 
          "Барои ин китоб матн ворид карда нашудааст. Лутфан бо админ дар тамос шавед.";

      bodyContent = Column(
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
      );
    }

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
              child: bodyContent,
            ),
          ),
        ],
      ),
    );
  }
}
