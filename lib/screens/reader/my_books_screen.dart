import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';
import 'book_details.dart';
import 'ebook_reader.dart';
import 'pdf_reader.dart';

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
    try {
      final response = await ApiService.get('/api/books/my-library');
      debugPrint('GET /api/books/my-library -> status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _books = data.map((b) => Book.fromJson(b)).toList();
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        String msg = 'Китобҳо ёфт нашуданд.';
        if (response.statusCode == 401) {
          msg = 'Сессия ба охир расид. Лутфан аз нав ворид шавед.';
        } else if (response.body.isNotEmpty) {
          try {
            final resData = jsonDecode(response.body);
            if (resData['message'] != null) {
              msg = resData['message'];
            }
          } catch (_) {}
        }
        setState(() {
          _error = msg;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('GET /api/books/my-library error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Хатогӣ дар пайвастшавӣ ба сервер: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final bodyWidget = Builder(
      builder: (context) {
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
                Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.redAccent.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Colors.white.withOpacity(0.6))),
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
                Icon(
                  Icons.menu_book_outlined,
                  size: 80,
                  color: Colors.white.withOpacity(0.2),
                ),
                const SizedBox(height: 20),
                Text(
                  'Шумо то ҳол ягон китоб нахаридаед',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _fetchMyBooks,
          color: Colors.deepPurpleAccent,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _books.length,
            itemBuilder: (context, index) {
              final book = _books[index];
              final canRead = book.bookType == 'Electronic' || book.bookType == 'Both';

              return GestureDetector(
                onTap: () {
                  if (book.pdfUrl != null && book.pdfUrl!.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PdfReaderScreen(book: book),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EbookReaderScreen(book: book),
                      ),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 80,
                          height: 110,
                          color: Colors.white.withOpacity(0.05),
                          child: book.imageUrl != null && book.imageUrl!.startsWith('http')
                              ? Image.network(
                                  book.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.book, color: Colors.white30, size: 40),
                                )
                              : const Icon(Icons.book, color: Colors.white30, size: 40),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              book.author,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildTypeTag(book.bookType),
                                const SizedBox(width: 8),
                                Text(
                                  book.categoryName,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (canRead) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (book.pdfUrl != null && book.pdfUrl!.isNotEmpty)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => PdfReaderScreen(book: book),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                                      label: const Text('Хондани PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  if (book.pdfUrl != null && book.pdfUrl!.isNotEmpty && book.content != null && book.content!.isNotEmpty)
                                    const SizedBox(width: 8),
                                  if (book.content != null && book.content!.isNotEmpty)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => EbookReaderScreen(book: book),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.menu_book, size: 14),
                                      label: const Text('Хондани матн', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurpleAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  if ((book.pdfUrl == null || book.pdfUrl!.isEmpty) && (book.content == null || book.content!.isEmpty))
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => EbookReaderScreen(book: book),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.menu_book, size: 14),
                                      label: const Text('Хондан', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurpleAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (!widget.showAppBar) {
      return bodyWidget;
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
      body: bodyWidget,
    );
  }
}
