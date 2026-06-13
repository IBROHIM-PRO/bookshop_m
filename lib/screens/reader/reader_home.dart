import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../notifications_feed.dart';
import 'book_details.dart';
import 'reader_tests.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';
import 'reader_stats.dart';
import 'specialties_screen.dart';
import 'my_books_screen.dart';
import 'leaderboard_screen.dart';
import '../../widgets/book_3d.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../chat/chat_list_screen.dart';

class ReaderHomeScreen extends StatefulWidget {
  const ReaderHomeScreen({super.key});

  @override
  State<ReaderHomeScreen> createState() => _ReaderHomeScreenState();
}

class _ReaderHomeScreenState extends State<ReaderHomeScreen> {
  int _currentIndex = 0;
  int _librarySubTab = 0; // 0 = Мағоза, 1 = Китобҳои ман
  bool _showHeaderToggle = false;
  List<Book> _books = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int? _selectedCategoryId;

  // Cart state — managed here and shared to CartScreen
  final List<CartItem> _cartItems = [];
  int _unreadNotificationCount = 0;
  StreamSubscription? _wsSubscription;

  // Retry logic
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _fetchData();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    _wsSubscription = WebSocketService().messageStream.listen((data) {
      final type = data['type'] as String?;
      if (type != 'login_approval_request' &&
          type != 'admin_login_approval_request' &&
          type != 'force_logout' &&
          type != 'chat_message' &&
          type != 'chat_message_edit' &&
          type != 'chat_message_delete') {
        if (!mounted) return;
        setState(() {
          _unreadNotificationCount++;
        });
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotificationCount() async {
    try {
      final unreadResponse = await ApiService.get('/api/notifications/unread-count');
      if (unreadResponse.statusCode == 200) {
        final unreadData = jsonDecode(unreadResponse.body);
        if (!mounted) return;
        setState(() {
          _unreadNotificationCount = unreadData['count'] ?? 0;
        });
      }
    } catch (_) {}
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
          _fetchNotificationCount();
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

    return Container(
      color: isDarkMode ? const Color(0xFF0D120E) : const Color(0xFFF1F8F4),
      child: _librarySubTab == 0
          ? RefreshIndicator(
              onRefresh: _fetchData,
              color: primaryColor,
              child: _buildShopContent(),
            )
          : const MyBooksScreen(showAppBar: false),
    );
  }

  Widget _buildShopContent() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1E7431)));
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

        // Grid View of Books (2 columns)
        Expanded(
          child: _filteredBooks.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.only(top: 100),
                      child: Text(
                        'Китобҳо ёфт нашуданд',
                        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 16),
                      ),
                    ),
                  ],
                )
              : GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.62,
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
                            // Book Cover (Flat)
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
                                  if (book.bookType != 'Electronic' && book.stockQuantity == 0)
                                    Positioned(
                                      top: 18,
                                      right: 18,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Тамом',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // Book Details
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                                        style: const TextStyle(
                                          color: Color(0xFFF43F5E), // Pink/Red like figma
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (canBuy)
                                        GestureDetector(
                                          onTap: () => _addToCart(book),
                                          child: Icon(
                                            Icons.shopping_cart_outlined,
                                            color: isDarkMode ? Colors.white70 : Colors.black87,
                                            size: 20,
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

  Widget _buildMenuIcon(Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 20, height: 2, color: color),
        const SizedBox(height: 4),
        Container(width: 14, height: 2, color: color),
      ],
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
      const SpecialtiesScreen(),
      const LeaderboardScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _currentIndex == 3
          ? null
          : (_currentIndex == 0
              ? AppBar(
                  backgroundColor: isDarkMode ? Colors.black : Colors.white,
                  elevation: 0,
                  centerTitle: true,
                  leadingWidth: 56,
                  leading: _showHeaderToggle
                      ? IconButton(
                          icon: Icon(Icons.close, color: textColor),
                          onPressed: () => setState(() => _showHeaderToggle = false),
                        )
                      : IconButton(
                          onPressed: () => setState(() => _showHeaderToggle = true),
                          icon: _buildMenuIcon(textColor),
                        ),
                  title: _showHeaderToggle
                      ? Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _librarySubTab = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _librarySubTab == 0 ? const Color(0xFF1E7431) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Мағоза',
                                    style: TextStyle(
                                      color: _librarySubTab == 0 ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black54),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _librarySubTab = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _librarySubTab == 1 ? const Color(0xFF1E7431) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Китобҳои ман',
                                    style: TextStyle(
                                      color: _librarySubTab == 1 ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black54),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          _librarySubTab == 0 ? 'Мағоза' : 'Китобҳои ман',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                  actions: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: SvgPicture.asset(
                            'assets/logo/logoheader/Frame 1984078266.svg',
                            height: 28,
                            colorFilter: ColorFilter.mode(
                              isDarkMode ? Colors.white : Colors.black,
                              BlendMode.srcIn,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const NotificationsFeedScreen())
                            ).then((_) => _fetchNotificationCount());
                          },
                        ),
                        if (_unreadNotificationCount > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$_unreadNotificationCount',
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
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: SvgPicture.asset(
                            'assets/logo/logoheader/Group 44376.svg',
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              isDarkMode ? Colors.white : Colors.black,
                              BlendMode.srcIn,
                            ),
                          ),
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
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$_cartCount',
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
                    const SizedBox(width: 8),
                  ],
                )
              : AppBar(
                  backgroundColor: isDarkMode ? Colors.black : Colors.white,
                  elevation: 0,
                  leading: null,
                  title: _currentIndex == 2
                      ? Text(
                          'Ихтисосҳо (ММТ)',
                          style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Салом, $userName!',
                              style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                  actions: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: SvgPicture.asset(
                                'assets/logo/logoheader/Frame 1984078266.svg',
                                height: 28,
                                colorFilter: ColorFilter.mode(
                                  isDarkMode ? Colors.white : Colors.black,
                                  BlendMode.srcIn,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const NotificationsFeedScreen())
                                ).then((_) => _fetchNotificationCount());
                              },
                            ),
                            if (_unreadNotificationCount > 0)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_unreadNotificationCount',
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
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: SvgPicture.asset(
                                'assets/logo/logoheader/Group 44376.svg',
                                height: 24,
                                colorFilter: ColorFilter.mode(
                                  isDarkMode ? Colors.white : Colors.black,
                                  BlendMode.srcIn,
                                ),
                              ),
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
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_cartCount',
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
                        if (_currentIndex == 2)
                          IconButton(
                            icon: Icon(
                              Icons.bookmark_border,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SpecialtiesScreen(isSavedOnly: true),
                                ),
                              );
                            },
                            tooltip: 'Ихтисосҳои захирашуда',
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                )),
      body: tabs[_currentIndex],
      bottomNavigationBar: Container(
        height: 73,
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
              _buildBottomNavItem(0, 'assets/logo/logosneckbar/Group 4.svg', 'Маркет', theme),
              _buildBottomNavItem(1, 'assets/logo/logosneckbar/Group 3.svg', 'Егзамен', theme),
              _buildBottomNavItem(2, 'assets/logo/logosneckbar/Group 2.svg', 'Ихтисосҳо', theme),
              _buildBottomNavItem(3, 'assets/logo/logosneckbar/Group 5.svg', 'Топ', theme),
              _buildBottomNavItem(4, 'assets/logo/logosneckbar/Group 6.svg', 'Профил', theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, String iconAsset, String label, ThemeData theme) {
    final isSelected = _currentIndex == index;
    final isDarkMode = theme.brightness == Brightness.dark;

    final Color activeColor = isDarkMode ? Colors.white : const Color(0xFF22873B);
    final Color inactiveColor = isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5);
    final Color itemColor = isSelected ? activeColor : inactiveColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(itemColor, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: itemColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
