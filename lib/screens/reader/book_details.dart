import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../widgets/book_3d.dart';
import 'ebook_reader.dart';

class BookDetailsScreen extends StatelessWidget {
  final Book book;
  final VoidCallback? onAddToCart;

  const BookDetailsScreen({super.key, required this.book, this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final canRead = book.bookType == 'Electronic' || book.bookType == 'Both';
    final canBuy = book.bookType == 'Electronic' || book.stockQuantity > 0;

    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Тафсилоти китоб', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3D Book Display Area (takes a flexible portion of the screen)
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Hero(
                        tag: 'book-cover-${book.id}',
                        child: VerticalBook3D(
                          imageUrl: book.imageUrl,
                          title: book.title,
                          width: 140,
                          height: 210,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        book.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Book Information Section
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  border: Border.all(color: theme.dividerColor),
                ),
                padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoBlock('Категория', book.categoryName, theme),
                        _buildInfoBlock('Намуд', _getTypeText(book.bookType), theme),
                        _buildInfoBlock('Нарх', '${book.price.toStringAsFixed(0)} TJS', theme),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Divider(color: theme.dividerColor),
                    const SizedBox(height: 16),

                    // Stock indicator
                    if (book.bookType != 'Electronic') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              book.stockQuantity > 0 ? Icons.check_circle_outline : Icons.error_outline,
                              color: textColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              book.stockQuantity > 0 ? 'Чопӣ: ${book.stockQuantity} адад' : 'Тамом шудааст',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Description Block (Scrollable inside the card)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Дар бораи китоб',
                            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                book.description ?? 'Тафсилоти китоб вуҷуд надорад.',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        if (canBuy && onAddToCart != null)
                          Expanded(
                            child: _buildActionButton(
                              context: context,
                              onPressed: () {
                                onAddToCart!();
                                Navigator.of(context).pop();
                              },
                              icon: Icons.add_shopping_cart,
                              label: 'Ба сабад',
                            ),
                          ),

                        if (canBuy && onAddToCart != null && canRead) const SizedBox(width: 16),

                        if (canRead)
                          Expanded(
                            child: _buildActionButton(
                              context: context,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => EbookReaderScreen(book: book)),
                                );
                              },
                              icon: Icons.menu_book,
                              label: 'Хондан',
                              isOutlined: true,
                            ),
                          ),

                        if (!canBuy && !canRead)
                          Expanded(
                            child: _buildActionButton(
                              context: context,
                              onPressed: null,
                              icon: Icons.not_interested,
                              label: 'Тамом шуд',
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
  }

  Widget _buildActionButton({
    required BuildContext context,
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    bool isOutlined = false,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  Widget _buildInfoBlock(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  String _getTypeText(String type) {
    if (type == 'Electronic') return 'Электронӣ';
    if (type == 'Printed') return 'Чопӣ';
    return 'Ҳарду';
  }
}
