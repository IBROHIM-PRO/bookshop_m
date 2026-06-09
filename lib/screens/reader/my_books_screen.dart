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
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    String text;
    if (type == 'Electronic') {
      text = 'Электронӣ';
    } else if (type == 'Printed') {
      text = 'Чопӣ';
    } else {
      text = 'Ҳарду';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.bold),
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
    final theme = Theme.of(context);
    final hasContent = book.content != null && book.content!.isNotEmpty;
    final canRead = book.bookType == 'Electronic' || book.bookType == 'Both';
    final textColor = theme.colorScheme.onSurface;
    final cardColor = theme.cardColor;

    return GestureDetector(
      onTap: () => _openBook(context, book, preferPdf: hasPdf),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.08) : const Color(0xFFD1E2D5)),
          boxShadow: theme.brightness == Brightness.dark ? [] : [
            BoxShadow(
              color: const Color(0xFF228B22).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 12,
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
                          onTap: () => _openBook(context, book, preferPdf: true),
                        ),
                      ),
                    if (hasPdf && hasContent) const SizedBox(width: 6),
                    if (hasContent)
                      Expanded(
                        child: _ReadButton(
                          label: 'Матн',
                          icon: Icons.menu_book,
                          onTap: () => _openBook(context, book, preferPdf: false),
                        ),
                      ),
                    if (!hasPdf && !hasContent)
                      Expanded(
                        child: _ReadButton(
                          label: 'Хондан',
                          icon: Icons.menu_book,
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
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = theme.colorScheme.onSurface.withOpacity(0.6);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: textColor),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: textColor),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchMyBooks,
              child: const Text('Боз кӯшиш кунед'),
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
            Icon(Icons.menu_book_outlined, size: 80, color: textColor.withOpacity(0.2)),
            const SizedBox(height: 20),
            Text(
              'Дар ҳоли ҳозир китобхонаи шумо холӣ аст.',
              style: TextStyle(color: subTextColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // ✅ GridView — 2 дар як қатор, мисли мағоза
    return RefreshIndicator(
      onRefresh: _fetchMyBooks,
      color: textColor,
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
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    if (_isLoading) {
      if (!widget.showAppBar) {
        return Center(
          child: CircularProgressIndicator(color: textColor),
        );
      }
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: textColor),
        ),
      );
    }

    if (!widget.showAppBar) {
      return _buildBody();
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Китобҳои ман',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor.withOpacity(0.7)),
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
  final VoidCallback onTap;

  const _ReadButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: textColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
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
