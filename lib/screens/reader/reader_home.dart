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
import 'leaderboard_screen.dart';
import '../../widgets/book_3d.dart';

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

  // Retry logic
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await _fetchWithRetry();
  }

  Future<void> _fetchWithRetry() async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        final booksResponse = await ApiService.get('/api/books?pageSize=50');
        final catsResponse = await ApiService.get('/api/categories');

        if (booksResponse.statusCode == 200 && catsResponse.statusCode == 200) {
          final booksData = jsonDecode(booksResponse.body);
          final catsData = jsonDecode(catsResponse.body);

          if (!mounted) return;
          setState(() {
            _books = (booksData['items'] as List).map((b) => Book.fromJson(b)).toList();
            _categories = catsData is List ? catsData : catsData['items'] ?? [];
            _isLoading = false;
            _retryCount = 0;
          });
          return;
        } else {
          attempt++;
          if (attempt < _maxRetries) {
            await Future.delayed(_retryDelay);
          } else {
            if (!mounted) return;
            setState(() => _isLoading = false);
          }
        }
      } catch (e) {
        attempt++;
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay);
        } else {
          if (!mounted) return;
          setState(() => _isLoading = false);
        }
      }
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
        backgroundColor: Colors.black,
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
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Premium Sub-Tab Switcher
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black12),
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
                              ? (isDarkMode ? Colors.black : Colors.white)
                              : (isDarkMode ? Colors.white60 : Colors.black54),
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
                              ? (isDarkMode ? Colors.black : Colors.white)
                              : (isDarkMode ? Colors.white60 : Colors.black54),
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
              ? RefreshIndicator(
                  onRefresh: _fetchData,
                  color: primaryColor,
                  child: _buildShopContent(),
                )
              : const MyBooksScreen(showAppBar: false),
        ),
      ],
    );
  }

  Widget _buildShopContent() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Ҷустуҷӯи китобҳо ё муаллифон...',
              hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: primaryColor),
              filled: true,
              fillColor: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDarkMode ? Colors.white10 : Colors.black12),
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
                backgroundColor: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
                labelStyle: TextStyle(
                  color: _selectedCategoryId == null
                      ? (isDarkMode ? Colors.black : Colors.white)
                      : (isDarkMode ? Colors.white60 : Colors.black54),
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
                    backgroundColor: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (isDarkMode ? Colors.black : Colors.white)
                          : (isDarkMode ? Colors.white60 : Colors.black54),
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
                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 16),
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
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFD1E2D5)),
                          boxShadow: isDarkMode ? [] : [
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
                            // Book Cover
                            Expanded(
                              child: Stack(
                                children: [
                                  Center(
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
                                    style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    book.author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${book.price.toStringAsFixed(0)} TJS',
                                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      if (canBuy)
                                        GestureDetector(
                                          onTap: () => _addToCart(book),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: textColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: textColor.withOpacity(0.2)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add_shopping_cart, color: textColor, size: 12),
                                                const SizedBox(width: 2),
                                                Text(
                                                  'Харид',
                                                  style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    String text;
    if (type == 'Electronic') {
      text = 'Электронӣ';
    } else if (type == 'Printed') {
      text = 'Чопӣ';
    } else {
      text = 'Ҳарду';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final user = Provider.of<AuthProvider>(context).currentUser;
    final String userName = user?.name ?? 'Хонанда';
    final primaryColor = theme.colorScheme.primary;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    final List<Widget> tabs = [
      _buildLibraryTab(),
      const ReaderTestsScreen(),
      const ReaderStatsScreen(),
      const LeaderboardScreen(),
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
              style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Theme Switcher Button
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              color: textColor,
            ),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
            tooltip: 'Ивази тема',
          ),

          // Notifications button
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: textColor),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: Text('Паёмҳо', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      backgroundColor: theme.appBarTheme.backgroundColor,
                      elevation: 0,
                      iconTheme: IconThemeData(color: textColor),
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
                icon: Icon(Icons.shopping_cart_outlined, color: textColor),
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
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_cartCount',
                        style: TextStyle(
                          color: isDarkMode ? Colors.black : Colors.white,
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
          color: theme.brightness == Brightness.dark ? theme.cardColor : Colors.white,
          border: Border(
            top: BorderSide(
              color: theme.brightness == Brightness.dark ? Colors.white12 : const Color(0xFFD1E2D5),
              width: 1.0,
            ),
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(0, Icons.library_books, 'Китобхона', theme),
              _buildBottomNavItem(1, Icons.assignment_turned_in, 'Тестҳо', theme),
              _buildBottomNavItem(2, Icons.bar_chart, 'Омор', theme),
              _buildBottomNavItem(3, Icons.leaderboard_outlined, 'Рейтинг', theme),
              _buildBottomNavItem(4, Icons.person_outline, 'Профил', theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label, ThemeData theme) {
    final isSelected = _currentIndex == index;
    final isDarkMode = theme.brightness == Brightness.dark;

    final Color activeColor = isDarkMode ? Colors.white : const Color(0xFF1E7431);
    final Color inactiveColor = isDarkMode ? Colors.white.withOpacity(0.4) : const Color(0xFF8A9A8E);
    final Color itemColor = isSelected ? activeColor : inactiveColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: itemColor,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: itemColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
