import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../notifications_feed.dart';
import 'book_details.dart';
import 'reader_tests.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';

class ReaderHomeScreen extends StatefulWidget {
  const ReaderHomeScreen({super.key});

  @override
  State<ReaderHomeScreen> createState() => _ReaderHomeScreenState();
}

class _ReaderHomeScreenState extends State<ReaderHomeScreen> {
  int _currentIndex = 0;
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
        content: Text('"${book.title}" сабад илова шуд'),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Сабад',
          textColor: Colors.white,
          onPressed: _openCart,
        ),
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
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
              prefixIcon: const Icon(Icons.search, color: Colors.deepPurpleAccent),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
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
                selectedColor: Colors.deepPurpleAccent,
                backgroundColor: Colors.white.withOpacity(0.05),
                labelStyle: TextStyle(
                  color: _selectedCategoryId == null ? Colors.white : Colors.white.withOpacity(0.6),
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
                    selectedColor: Colors.deepPurpleAccent,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white.withOpacity(0.6)),
                    onSelected: (selected) => setState(() => _selectedCategoryId = selected ? catId : null),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Books List
        Expanded(
          child: _filteredBooks.isEmpty
              ? Center(
                  child: Text(
                    'Китобҳо ёфт нашуданд',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
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
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            // Book Cover
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 80,
                                height: 110,
                                color: Colors.white.withOpacity(0.05),
                                child: book.imageUrl != null && book.imageUrl!.startsWith('http')
                                    ? Image.network(book.imageUrl!, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.book, color: Colors.white30, size: 40))
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
                                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    book.author,
                                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildTypeTag(book.bookType),
                                      const SizedBox(width: 6),
                                      if (book.bookType != 'Electronic' && book.stockQuantity == 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('Тамом', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${book.price.toStringAsFixed(0)} TJS',
                                        style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      if (canBuy)
                                        GestureDetector(
                                          onTap: () => _addToCart(book),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.deepPurpleAccent.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add_shopping_cart, color: Colors.deepPurpleAccent, size: 14),
                                                SizedBox(width: 4),
                                                Text('Харид', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
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
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final String userName = user?.name ?? 'Хонанда';

    final List<Widget> tabs = [
      _buildLibraryTab(),
      const ReaderTestsScreen(),
      const NotificationsFeedScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15102A),
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
                    decoration: const BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_cartCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF15102A),
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.white.withOpacity(0.4),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Китобхона'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in), label: 'Тестҳо'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Паёмҳо'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Профил'),
        ],
      ),
    );
  }
}
