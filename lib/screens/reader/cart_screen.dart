import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/book.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import 'my_orders_screen.dart';

// ─── Simple Cart Model ──────────────────────────────────────────────────────

class CartItem {
  final Book book;
  int quantity;

  CartItem({required this.book, this.quantity = 1});
}

// ─── Cart Screen ────────────────────────────────────────────────────────────

class CartScreen extends StatefulWidget {
  final List<CartItem> cartItems;

  const CartScreen({super.key, required this.cartItems});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isSubmitting = false;
  int _subTab = 0; // 0 = Cart, 1 = Orders
  List<CartItem> get _items => widget.cartItems;

  double get _totalPrice =>
      _items.fold(0, (sum, item) => sum + item.book.price * item.quantity);

  void _increment(CartItem item) {
    setState(() => item.quantity++);
  }

  void _decrement(CartItem item) {
    if (item.quantity > 1) {
      setState(() => item.quantity--);
    } else {
      setState(() => _items.remove(item));
    }
  }

  void _remove(CartItem item) {
    setState(() => _items.remove(item));
  }

  Future<void> _placeOrder() async {
    if (_items.isEmpty) return;

    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Лутфан аввал ворид шавед'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final orderItems = _items
          .map((item) => {'bookId': item.book.id, 'quantity': item.quantity})
          .toList();

      final body = {
        'customerName': user.name,
        'customerEmail': user.email,
        'customerPhone': user.phone ?? '',
        'orderItems': orderItems,
      };

      final response = await ApiService.post('/api/orders', body);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _items.clear();
        _showSuccessDialog();
      } else {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['message'] ?? 'Хатогӣ дар фиристодани заявка'),
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Хатогӣ дар пайвастшавӣ ба сервер'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: isDarkMode ? Colors.white10 : Colors.black12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: textColor, size: 72),
            const SizedBox(height: 16),
            Text(
              'Заявка фиристода шуд!',
              style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Заявкаи шумо қабул шуд. Админ онро тафтиш карда тасдиқ хоҳад кард.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor.withOpacity(0.7), height: 1.5),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
              },
              child: const Text(
                'Фаҳмо',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          _subTab == 0 ? 'Сабади харид (${_items.length})' : 'Заявкаҳои ман',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(
        children: [
          // Sub-Tab Switcher
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode ? Colors.white10 : const Color(0xFF1E7431).withOpacity(0.15),
                ),
                boxShadow: isDarkMode ? [] : [
                  BoxShadow(
                    color: const Color(0xFF228B22).withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _subTab = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _subTab == 0
                              ? (isDarkMode ? primaryColor : const Color(0xFF1E7431))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Сабад',
                          style: TextStyle(
                            color: _subTab == 0
                                ? Colors.white
                                : (isDarkMode ? Colors.white60 : const Color(0xFF657367)),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _subTab = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _subTab == 1
                              ? (isDarkMode ? primaryColor : const Color(0xFF1E7431))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Заявкаҳо',
                          style: TextStyle(
                            color: _subTab == 1
                                ? Colors.white
                                : (isDarkMode ? Colors.white60 : const Color(0xFF657367)),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
            child: _subTab == 1
                ? const MyOrdersScreen(showAppBar: false)
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 80, color: textColor.withOpacity(0.2)),
                            const SizedBox(height: 20),
                            Text(
                              'Сабади харид холӣ аст',
                              style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isDarkMode ? Colors.white10 : const Color(0xFF1E7431).withOpacity(0.15),
                                    ),
                                    boxShadow: isDarkMode ? [] : [
                                      BoxShadow(
                                        color: const Color(0xFF228B22).withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Book cover
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 60,
                                          height: 80,
                                          color: textColor.withOpacity(0.05),
                                          child: item.book.imageUrl != null &&
                                                  item.book.imageUrl!.startsWith('http')
                                              ? CachedNetworkImage(
                                                  imageUrl: item.book.imageUrl!, 
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) => Icon(Icons.book, color: textColor.withOpacity(0.3)),
                                                  errorWidget: (context, url, error) => Icon(Icons.book, color: textColor.withOpacity(0.3)),
                                                )
                                              : Icon(Icons.book, color: textColor.withOpacity(0.3), size: 30),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.book.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.book.price.toStringAsFixed(0)} TJS',
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          // Quantity controls
                                          Row(
                                            children: [
                                              _qtyButton(Icons.remove, () => _decrement(item), isDarkMode),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                child: Text(
                                                  '${item.quantity}',
                                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                              ),
                                              _qtyButton(Icons.add, () => _increment(item), isDarkMode),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          GestureDetector(
                                            onTap: () => _remove(item),
                                            child: Text('Нест кардан',
                                                style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontSize: 11, decoration: TextDecoration.underline)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          // Bottom summary
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                              border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Ҷамъ (${_items.length} китоб):',
                                        style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 15)),
                                    Text(
                                      '${_totalPrice.toStringAsFixed(0)} TJS',
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : _placeOrder,
                                    child: _isSubmitting
                                        ? SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              color: isDarkMode ? Colors.black : Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            '🛒  Фармоиш додан',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, bool isDarkMode) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFEBF3ED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : const Color(0xFF1E7431).withOpacity(0.15),
          ),
        ),
        child: Icon(
          icon,
          color: isDarkMode ? Colors.white : const Color(0xFF1E7431),
          size: 16,
        ),
      ),
    );
  }
}
