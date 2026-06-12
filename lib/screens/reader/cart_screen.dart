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
    final bodyBgColor = isDarkMode ? const Color(0xFF0D120E) : const Color(0xFFF1F8F4);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          _subTab == 0 ? 'Сабад' : 'Чекҳо',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        color: bodyBgColor,
        child: Column(
          children: [
            // Sub-Tab Switcher
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _subTab = 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _subTab == 0
                                ? const Color(0xFF1E7431)
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
                                ? const Color(0xFF1E7431)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Чекҳо',
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: _items.length,
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? const Color(0xFF161E18) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDarkMode
                                            ? Colors.white24
                                            : const Color(0xFF1E7431).withOpacity(0.6),
                                        width: 1.2,
                                      ),
                                      boxShadow: isDarkMode ? [] : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Book Cover on the left
                                          Container(
                                            width: 90,
                                            height: 120,
                                            color: textColor.withOpacity(0.05),
                                            child: item.book.imageUrl != null &&
                                                    item.book.imageUrl!.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: ApiService.getFullImageUrl(item.book.imageUrl!),
                                                    fit: BoxFit.cover,
                                                    placeholder: (context, url) => Center(
                                                      child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
                                                    ),
                                                    errorWidget: (context, url, error) => Icon(
                                                      Icons.book,
                                                      color: textColor.withOpacity(0.3),
                                                      size: 30,
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.book,
                                                    color: textColor.withOpacity(0.3),
                                                    size: 30,
                                                  ),
                                          ),
                                          const SizedBox(width: 12),

                                          // Book Details on the right
                                          Expanded(
                                            child: Container(
                                              height: 120,
                                              padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Category & Delete Row
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          item.book.categoryName.isNotEmpty
                                                              ? item.book.categoryName
                                                              : 'Китоб',
                                                          style: TextStyle(
                                                            color: textColor.withOpacity(0.5),
                                                            fontSize: 12,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () => _remove(item),
                                                        child: Icon(
                                                          Icons.close,
                                                          color: isDarkMode ? Colors.white60 : Colors.black,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  
                                                  // Title
                                                  Text(
                                                    item.book.title,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: textColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),

                                                  // Author
                                                  Text(
                                                    item.book.author,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: textColor.withOpacity(0.6),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const Spacer(),

                                                  // Quantity & Price Row
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      // Qty Selector
                                                      Row(
                                                        children: [
                                                          _qtyButton(Icons.remove, () => _decrement(item), isDarkMode),
                                                          Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                                            child: Text(
                                                              '${item.quantity}',
                                                              style: TextStyle(
                                                                color: textColor,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                          ),
                                                          _qtyButton(Icons.add, () => _increment(item), isDarkMode),
                                                        ],
                                                      ),

                                                      // Price
                                                      Text(
                                                        '${(item.book.price * item.quantity).toStringAsFixed(0)} TJS',
                                                        style: TextStyle(
                                                          color: textColor,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Bottom summary
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Column(
                                children: [
                                  Divider(
                                    color: isDarkMode ? Colors.white24 : Colors.black26,
                                    thickness: 1.0,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${_totalPrice.toStringAsFixed(0)} TJS',
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isSubmitting ? null : _placeOrder,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E7431),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Фармоиш додан',
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
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, bool isDarkMode) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          color: isDarkMode ? Colors.black : Colors.white,
          size: 14,
        ),
      ),
    );
  }
}
