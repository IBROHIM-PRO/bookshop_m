import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../notifications_feed.dart';
import 'book_details.dart';
import 'reader_tests.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';
import 'reader_stats.dart';
import 'my_books_screen.dart';

class ReaderHomeScreen extends StatefulWidget {
  const ReaderHomeScreen({super.key});

  @override
  State<ReaderHomeScreen> createState() => _ReaderHomeScreenState();
}

class _ReaderHomeScreenState extends State<ReaderHomeScreen> {
  int _currentIndex = 0;
  int _librarySubTab = 0; // 0 = Мағоза, 1 = Китобҳои ман
  List<Book> _books = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int? _selectedCategoryId;

  // Cart state — managed here and shared to CartScreen
  final List<CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final booksResponse = await ApiService.get('/api/books?pageSize=50');
      final catsResponse = await ApiService.get('/api/categories');

      if (booksResponse.statusCode == 200 && catsResponse.statusCode == 200) {
        final booksData = jsonDecode(booksResponse.body);
        final catsData = jsonDecode(catsResponse.body);

        setState(() {
          _books = (booksData['items'] as List).map((b) => Book.fromJson(b)).toList();
          _categories = catsData is List ? catsData : catsData['items'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Book> get _filteredBooks {
    return _books.where((book) {
      final matchesSearch = book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          book.author.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategoryId == null || book.categoryId == _selectedCategoryId;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _addToCart(Book book) {
    setState(() {
      final existing = _cartItems.indexWhere((i) => i.book.id == book.id);
      if (existing >= 0) {
        _cartItems[existing].quantity++;
      } else {
        _cartItems.add(CartItem(book: book));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${book.title}" ба сабад илова шуд!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CartScreen(cartItems: _cartItems),
      ),
    ).then((_) => setState(() {}));
  }

  int get _cartCount => _cartItems.fold(0, (sum, i) => sum + i.quantity);

  Widget _buildLibraryTab() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Column(
      children: [
        // Premium Sub-Tab Switcher
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _librarySubTab = 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _librarySubTab == 0 ? primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Мағоза',
                        style: TextStyle(
                          color: _librarySubTab == 0
                              ? (theme.brightness == Brightness.dark && primaryColor == Colors.white ? Colors.black : Colors.white)
                              : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _librarySubTab = 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _librarySubTab == 1 ? primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Китобҳои ман',
                        style: TextStyle(
                          color: _librarySubTab == 1
                              ? (theme.brightness == Brightness.dark && primaryColor == Colors.white ? Colors.black : Colors.white)
                              : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        Expanded(
          child: _librarySubTab == 0
              ? _buildShopContent()
              : const MyBooksScreen(showAppBar: false),
        ),
      ],
    );
  }

  Widget _buildCategoryBooksView() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final filtered = _books.where((book) {
      final matchesSearch = book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          book.author.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    final Map<String, List<Book>> groupedBooks = {};
    for (var cat in _categories) {
      final catName = cat['name'] as String;
      final catId = cat['id'] as int;
      final catBooks = filtered.where((b) => b.categoryId == catId).toList();
      if (catBooks.isNotEmpty) {
        groupedBooks[catName] = catBooks;
      }
    }

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ҷустуҷӯи китобҳо...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: primaryColor),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        Expanded(
          child: groupedBooks.isEmpty
              ? Center(
                  child: Text(
                    'Китобҳо ёфт нашуданд',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: groupedBooks.keys.length,
                  itemBuilder: (context, catIndex) {
                    final catName = groupedBooks.keys.elementAt(catIndex);
                    final catBooks = groupedBooks[catName]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Text(
                            catName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: catBooks.length,
                            itemBuilder: (context, idx) {
                              final book = catBooks[idx];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => BookDetailsScreen(
                                        book: book,
                                        onAddToCart: () => _addToCart(book),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 120,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            color: Colors.white.withOpacity(0.05),
                                            child: book.imageUrl != null && book.imageUrl!.startsWith('http')
                                                ? Image.network(
                                                    book.imageUrl!,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.book, color: Colors.white30, size: 40),
                                                  )
                                                : const Center(child: Icon(Icons.book, color: Colors.white30, size: 40)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        book.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        book.author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Divider(color: Colors.white.withOpacity(0.08)),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildShopContent() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ҷустуҷӯи китобҳо ё муаллифон...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: primaryColor),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
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
                selectedColor: primaryColor,
                backgroundColor: Colors.white.withOpacity(0.05),
                labelStyle: TextStyle(
                  color: _selectedCategoryId == null
                      ? (theme.brightness == Brightness.dark && primaryColor == Colors.white ? Colors.black : Colors.white)
                      : Colors.white.withOpacity(0.6),
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
                    selectedColor: primaryColor,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (theme.brightness == Brightness.dark && primaryColor == Colors.white ? Colors.black : Colors.white)
                          : Colors.white.withOpacity(0.6),
                    ),
                    onSelected: (selected) => setState(() => _selectedCategoryId = selected ? catId : null),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Grid View of Books (2 columns)
        Expanded(
          child: _filteredBooks.isEmpty
              ? Center(
                  child: Text(
                    'Китобҳо ёфт нашуданд',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: _filteredBooks.length,
                  itemBuilder: (context, index) {
                    final book = _filteredBooks[index];
                    final canBuy = book.stockQuantity > 0 || book.bookType == 'Electronic';
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BookDetailsScreen(
                              book: book,
                              onAddToCart: () => _addToCart(book),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Book Cover
                            Expanded(
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    child: Container(
                                      width: double.infinity,
                                      color: Colors.white.withOpacity(0.05),
                                      child: book.imageUrl != null && book.imageUrl!.startsWith('http')
                                          ? Image.network(
                                              book.imageUrl!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.book, color: Colors.white30, size: 40),
                                            )
                                          : const Center(child: Icon(Icons.book, color: Colors.white30, size: 40)),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: _buildTypeTag(book.bookType),
                                  ),
                                  if (book.bookType != 'Electronic' && book.stockQuantity == 0)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('Тамом', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // Book Details
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    book.author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${book.price.toStringAsFixed(0)} TJS',
                                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      if (canBuy)
                                        GestureDetector(
                                          onTap: () => _addToCart(book),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add_shopping_cart, color: primaryColor, size: 12),
                                                const SizedBox(width: 2),
                                                Text(
                                                  'Харид',
                                                  style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTypeTag(String type) {
    final isBw = Provider.of<ThemeProvider>(context, listen: false).isBlackAndWhite;
    Color color;
    String text;
    if (type == 'Electronic') {
      color = isBw ? Colors.white : Colors.teal;
      text = 'Электронӣ';
    } else if (type == 'Printed') {
      color = isBw ? Colors.white70 : Colors.orangeAccent;
      text = 'Чопӣ';
    } else {
      color = isBw ? Colors.white60 : Colors.blueAccent;
      text = 'Ҳарду';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: isBw ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final String userName = user?.name ?? 'Хонанда';
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final List<Widget> tabs = [
      _buildLibraryTab(),
      const ReaderTestsScreen(),
      const ReaderStatsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Салом, $userName!',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Мутолиаи хушро таманно дорем',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
        actions: [
          // Theme Switcher Button
          IconButton(
            icon: Icon(
              Provider.of<ThemeProvider>(context).isBlackAndWhite
                  ? Icons.wb_sunny_outlined
                  : Icons.dark_mode_outlined,
              color: Colors.white,
            ),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
            tooltip: 'Ивази тема',
          ),

          // Notifications button
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Паёмҳо', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      backgroundColor: theme.appBarTheme.backgroundColor,
                      elevation: 0,
                      iconTheme: const IconThemeData(color: Colors.white),
                    ),
                    body: const NotificationsFeedScreen(),
                  ),
                ),
              );
            },
            tooltip: 'Паёмҳо',
          ),

          // Cart button with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                onPressed: _openCart,
                tooltip: 'Сабади харид',
              ),
              if (_cartCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: primaryColor == Colors.white ? Colors.white : Colors.teal,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_cartCount',
                        style: TextStyle(
                          color: primaryColor == Colors.white ? Colors.black : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(0, Icons.library_books, 'Китобхона', theme),
              _buildBottomNavItem(1, Icons.assignment_turned_in, 'Тестҳо', theme),
              _buildBottomNavItem(2, Icons.bar_chart, 'Омор', theme),
              _buildBottomNavItem(3, Icons.person_outline, 'Профил', theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label, ThemeData theme) {
    final isSelected = _currentIndex == index;
    final isBw = Provider.of<ThemeProvider>(context).isBlackAndWhite;
    final highlightColor = isBw ? Colors.black : const Color(0xFF6B4FB3);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? highlightColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
