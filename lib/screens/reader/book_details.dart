import 'package:flutter/material.dart';
import '../../models/book.dart';
import 'ebook_reader.dart';

class BookDetailsScreen extends StatelessWidget {
  final Book book;
  final VoidCallback? onAddToCart;

  const BookDetailsScreen({super.key, required this.book, this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final canRead = book.bookType == 'Electronic' || book.bookType == 'Both';
    final canBuy = book.bookType == 'Electronic' || book.stockQuantity > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15102A),
        elevation: 0,
        title: const Text('Тафсилоти китоб', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF15102A),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Hero(
                    tag: 'book-cover-${book.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 150,
                        height: 220,
                        color: Colors.white.withOpacity(0.05),
                        child: book.imageUrl != null && book.imageUrl!.startsWith('http')
                            ? Image.network(
                                book.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.book, size: 80, color: Colors.white30),
                              )
                            : const Icon(Icons.book, size: 80, color: Colors.white30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    book.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    book.author,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoBlock('Категория', book.categoryName),
                      _buildInfoBlock('Намуд', _getTypeText(book.bookType)),
                      _buildInfoBlock('Нарх', '${book.price.toStringAsFixed(0)} TJS'),
                    ],
                  ),

                  // Stock indicator for printed
                  if (book.bookType != 'Electronic') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (book.stockQuantity > 0 ? Colors.teal : Colors.redAccent).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            book.stockQuantity > 0 ? Icons.inventory_2_outlined : Icons.remove_shopping_cart_outlined,
                            color: book.stockQuantity > 0 ? Colors.teal : Colors.redAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            book.stockQuantity > 0
                                ? 'Дар анбор: ${book.stockQuantity} нусха'
                                : 'Тамом шуд',
                            style: TextStyle(
                              color: book.stockQuantity > 0 ? Colors.teal : Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Description
                  const Text(
                    'Дар бораи китоб',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    book.description ?? 'Тавсифи китоб мавҷуд нест.',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15, height: 1.6),
                  ),

                  const SizedBox(height: 36),

                  // Action Buttons
                  Row(
                    children: [
                      // Add to Cart
                      if (canBuy && onAddToCart != null)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              onAddToCart!();
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text('Ба сабад', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),

                      if (canBuy && onAddToCart != null && canRead) const SizedBox(width: 12),

                      // Read Book
                      if (canRead)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => EbookReaderScreen(book: book)),
                              );
                            },
                            icon: const Icon(Icons.menu_book, size: 18),
                            label: const Text('Хондан', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurpleAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),

                      if (!canBuy && !canRead)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              disabledBackgroundColor: Colors.white.withOpacity(0.05),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Тамом шудааст',
                                style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold)),
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
  }

  Widget _buildInfoBlock(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _getTypeText(String type) {
    if (type == 'Electronic') return 'Электронӣ';
    if (type == 'Printed') return 'Чопӣ';
    return 'Ҳарду';
  }
}
