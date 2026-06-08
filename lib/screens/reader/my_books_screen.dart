import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';
import 'book_details.dart';
import 'ebook_reader.dart';
import 'pdf_reader.dart';
import '../../widgets/book_3d.dart';

class MyBooksScreen extends StatefulWidget {
  final bool showAppBar;
  const MyBooksScreen({super.key, this.showAppBar = true});

  @override
  State<MyBooksScreen> createState() => _MyBooksScreenState();
}

class _MyBooksScreenState extends State<MyBooksScreen> {
  List<Book> _books = [];
  bool _isLoading = true;
  String? _error;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _fetchMyBooks();
  }

  Future<void> _fetchMyBooks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _fetchWithRetry();
  }

  Future<void> _fetchWithRetry() async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await ApiService.get('/api/books/my-library');
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          if (!mounted) return;
          setState(() {
            _books = data.map((b) => Book.fromJson(b)).toList();
            _isLoading = false;
          });
          return;
        } else {
          if (attempt < _maxRetries - 1) {
            await Future.delayed(_retryDelay);
            continue;
          }
          if (!mounted) return;
          String msg = 'Китобҳо ёфт нашуданд.';
          if (response.statusCode == 401) {
            msg = 'Сессия ба охир расид. Лутфан аз нав ворид шавед.';
          } else if (response.body.isNotEmpty) {
            try {
              final resData = jsonDecode(response.body);
              if (resData['message'] != null) msg = resData['message'];
            } catch (_) {}
          }
          setState(() {
            _error = msg;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (attempt < _maxRetries - 1) {
          await Future.delayed(_retryDelay);
          continue;
        }
        if (!mounted) return;
        setState(() {
          _error = 'Хатогӣ дар пайвастшавӣ ба сервер';
          _isLoading = false;
        });
      }
    }
  }

  // Навъи китоб — tag ранги
  Widget _buildTypeTag(String type) {
    Color color;
    String text;
    if (type == 'Electronic') {
      color = Colors.teal;
      text = 'Электронӣ';
    } else if (type == 'Printed') {
      color = Colors.orangeAccent;
      text = 'Чопӣ';
    } else {
      color = Colors.blueAccent;
      text = 'Ҳарду';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Тугмаи хондан
  void _openBook(BuildContext context, Book book, {bool preferPdf = false}) {
    if (preferPdf && book.pdfUrl != null && book.pdfUrl!.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PdfReaderScreen(book: book)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EbookReaderScreen(book: book)),
      );
    }
  }

  // ✅ Карти китоб барои grid
  Widget _buildBookCard(Book book) {
    final hasPdf = book.pdfUrl != null && book.pdfUrl!.isNotEmpty;
    final hasContent = book.content != null && book.content!.isNotEmpty;
    final canRead = book.bookType == 'Electronic' || book.bookType == 'Both';

    return GestureDetector(
      onTap: () => _openBook(context, book, preferPdf: hasPdf),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Муқоваи китоб
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Book3D(
                    imageUrl: book.imageUrl,
                    title: book.title,
                    width: 100,
                    height: 145,
                    depth: 18,
                  ),
                ),
              ),
            ),

            // Маълумоти китоб
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildTypeTag(book.bookType),
                ],
              ),
            ),

            // Тугмаҳои хондан
            if (canRead)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
                child: Row(
                  children: [
                    if (hasPdf)
                      Expanded(
                        child: _ReadButton(
                          label: 'PDF',
                          icon: Icons.picture_as_pdf,
                          color: Colors.redAccent,
                          onTap: () => _openBook(context, book, preferPdf: true),
                        ),
                      ),
                    if (hasPdf && hasContent) const SizedBox(width: 6),
                    if (hasContent)
                      Expanded(
                        child: _ReadButton(
                          label: 'Матн',
                          icon: Icons.menu_book,
                          color: Colors.deepPurpleAccent,
                          onTap: () => _openBook(context, book, preferPdf: false),
                        ),
                      ),
                    if (!hasPdf && !hasContent)
                      Expanded(
                        child: _ReadButton(
                          label: 'Хондан',
                          icon: Icons.menu_book,
                          color: Colors.deepPurpleAccent,
                          onTap: () => _openBook(context, book),
                        ),
                      ),
                  ],
                ),
              )
            else
              const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.redAccent.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchMyBooks,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Боз кӯшиш кунед', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 80, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 20),
            Text(
              'Шумо то ҳол ягон китоб нахаридаед',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
            ),
          ],
        ),
      );
    }

    // ✅ GridView — 2 дар як қатор, мисли мағоза
    return RefreshIndicator(
      onRefresh: _fetchMyBooks,
      color: Colors.deepPurpleAccent,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,        // ✅ 2 дар як қатор
          crossAxisSpacing: 12,     // фосила байни сутунҳо
          mainAxisSpacing: 12,      // фосила байни қаторҳо
          childAspectRatio: 0.58,   // баландӣ/паҳнои карт
        ),
        itemCount: _books.length,
        itemBuilder: (context, index) => _buildBookCard(_books[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAppBar) {
      return _buildBody();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15102A),
        elevation: 0,
        title: const Text(
          'Китобҳои ман',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _fetchMyBooks,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}

// ✅ Алоҳида widget барои тугмаи хондан — код тозатар
class _ReadButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReadButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}