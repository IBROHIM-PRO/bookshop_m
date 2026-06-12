import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  int? _selectedCategoryId;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _fetchMyBooks();
  }

  List<Book> get _filteredBooks {
    return _books.where((book) {
      final matchesSearch = book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          book.author.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategoryId == null || book.categoryId == _selectedCategoryId;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _fetchMyBooks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final catsResponse = await ApiService.get('/api/categories');
      if (catsResponse.statusCode == 200) {
        final catsData = jsonDecode(catsResponse.body);
        _categories = catsData is List ? catsData : catsData['items'] ?? [];
      }
    } catch (_) {}
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
    final isDarkMode = theme.brightness == Brightness.dark;
    final hasContent = book.content != null && book.content!.isNotEmpty;
    final canRead = book.bookType == 'Electronic' || book.bookType == 'Both';
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: () => _openBook(context, book, preferPdf: hasPdf),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF161E18) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFF1E7431).withOpacity(0.15),
            width: 1.2,
          ),
          boxShadow: isDarkMode ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image (Flat)
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: ApiService.getFullImageUrl(book.imageUrl),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (context, url) => Container(
                          color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E7431)),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    left: 18,
                    child: _buildTypeTag(book.bookType),
                  ),
                ],
              ),
            ),

            // Book Details
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Read Buttons
            if (canRead)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = textColor.withOpacity(0.6);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E7431)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E7431),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Боз кӯшиш кунед'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Чустучу',
              hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
              suffixIcon: Icon(Icons.search, color: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431)),
              filled: true,
              fillColor: isDarkMode ? const Color(0xFF161E18) : const Color(0xFFE8ECE9),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey.shade300, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E7431), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        // Category Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Ҳама'),
                selected: _selectedCategoryId == null,
                selectedColor: const Color(0xFF1E7431),
                backgroundColor: isDarkMode ? const Color(0xFF161E18) : Colors.white,
                labelStyle: TextStyle(
                  color: _selectedCategoryId == null
                      ? Colors.white
                      : (isDarkMode ? Colors.white70 : const Color(0xFF1E7431)),
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _selectedCategoryId == null
                        ? const Color(0xFF1E7431)
                        : const Color(0xFF1E7431).withOpacity(0.5),
                    width: 1.2,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCategoryId = null);
                },
              ),
              const SizedBox(width: 8),
              ..._categories.map((cat) {
                final catId = cat['id'] as int;
                final catName = cat['name'] as String;
                final isSelected = _selectedCategoryId == catId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(catName),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1E7431),
                    backgroundColor: isDarkMode ? const Color(0xFF161E18) : Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDarkMode ? Colors.white70 : const Color(0xFF1E7431)),
                      fontWeight: FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF1E7431)
                            : const Color(0xFF1E7431).withOpacity(0.5),
                        width: 1.2,
                      ),
                    ),
                    onSelected: (selected) => setState(() => _selectedCategoryId = selected ? catId : null),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: _filteredBooks.isEmpty
              ? Center(
                  child: Text(
                    'Китобҳо ёфт нашуданд',
                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchMyBooks,
                  color: const Color(0xFF1E7431),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.58,
                    ),
                    itemCount: _filteredBooks.length,
                    itemBuilder: (context, index) => _buildBookCard(_filteredBooks[index]),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoading) {
      if (!widget.showAppBar) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E7431)),
        );
      }
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF0D120E) : const Color(0xFFF1F8F4),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E7431)),
        ),
      );
    }

    if (!widget.showAppBar) {
      return _buildBody();
    }

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0D120E) : const Color(0xFFF1F8F4),
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
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
    final isDarkMode = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E7431).withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E7431).withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF1E7431)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1E7431),
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
