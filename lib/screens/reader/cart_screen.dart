import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        const SnackBar(content: Text('Лутфан аввал ворид шавед'), backgroundColor: Colors.redAccent),
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
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хатогӣ дар пайвастшавӣ ба сервер'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showSuccessDialog() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isBw = Provider.of<ThemeProvider>(context, listen: false).isBlackAndWhite;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isBw ? Colors.black : const Color(0xFF1E173E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: isBw ? const BorderSide(color: Colors.white24) : BorderSide.none,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: isBw ? Colors.white : Colors.teal, size: 72),
            const SizedBox(height: 16),
            Text(
              'Заявка фиристода шуд!',
              style: TextStyle(color: isBw ? Colors.white : Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Заявкаи шумо қабул шуд. Админ онро тафтиш карда тасдиқ хоҳад кард.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true); // Return true = order placed
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(
                'Фаҳмо',
                style: TextStyle(
                  color: isBw ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
    final primaryColor = theme.colorScheme.primary;
    final isBw = Provider.of<ThemeProvider>(context).isBlackAndWhite;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          _subTab == 0 ? 'Сабади харид (${_items.length})' : 'Заявкаҳои ман',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _subTab = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _subTab == 0 ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Сабад',
                          style: TextStyle(
                            color: _subTab == 0
                                ? (isBw ? Colors.black : Colors.white)
                                : Colors.white60,
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
                          color: _subTab == 1 ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Заявкаҳо',
                          style: TextStyle(
                            color: _subTab == 1
                                ? (isBw ? Colors.black : Colors.white)
                                : Colors.white60,
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
                            Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 20),
                            Text(
                              'Сабади харид холӣ аст',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
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
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                                  ),
                                  child: Row(
                                    children: [
                                      // Book cover
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 60,
                                          height: 80,
                                          color: Colors.white.withOpacity(0.05),
                                          child: item.book.imageUrl != null &&
                                                  item.book.imageUrl!.startsWith('http')
                                              ? Image.network(item.book.imageUrl!, fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(Icons.book, color: Colors.white30))
                                              : const Icon(Icons.book, color: Colors.white30, size: 30),
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
                                              style: const TextStyle(
                                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.book.price.toStringAsFixed(0)} TJS',
                                              style: TextStyle(
                                                color: isBw ? Colors.white70 : Colors.deepPurpleAccent,
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
                                              _qtyButton(Icons.remove, () => _decrement(item)),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                child: Text(
                                                  '${item.quantity}',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                              ),
                                              _qtyButton(Icons.add, () => _increment(item)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          GestureDetector(
                                            onTap: () => _remove(item),
                                            child: const Text('Нест кардан',
                                                style: TextStyle(color: Colors.redAccent, fontSize: 11)),
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
                              border: isBw ? Border.all(color: Colors.white10) : null,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Ҷамъ (${_items.length} китоб):',
                                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15)),
                                    Text(
                                      '${_totalPrice.toStringAsFixed(0)} TJS',
                                      style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
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
                                      backgroundColor: primaryColor,
                                      disabledBackgroundColor: primaryColor.withOpacity(0.3),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: _isSubmitting
                                        ? SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              color: isBw ? Colors.black : Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            '🛒  Фармоиш додан',
                                            style: TextStyle(
                                              color: isBw ? Colors.black : Colors.white,
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

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }
}
