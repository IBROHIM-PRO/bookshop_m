import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/book.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import 'ebook_reader.dart';

class BookDetailsScreen extends StatelessWidget {
  final Book book;
  final VoidCallback? onAddToCart;

  const BookDetailsScreen({super.key, required this.book, this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final canRead = book.bookType == 'Electronic' || book.bookType == 'Both';
    final canBuy = book.bookType == 'Electronic' || book.stockQuantity > 0;

    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final bodyBgColor = isDarkMode ? const Color(0xFF0D120E) : const Color(0xFFF1F8F4);
    final primaryColor = isDarkMode ? const Color(0xFFA3E635) : const Color(0xFF1E7431);

    final rating = "${(4.0 + (book.id % 10) * 0.1).toStringAsFixed(2)}/5";

    return Scaffold(
      backgroundColor: bodyBgColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Маълумоти китоб',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book Title
              Center(
                child: Text(
                  book.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Image and Details Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flat Book Cover with rounded corners and border
                  Container(
                    width: 140,
                    height: 205,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                        width: 1.5,
                      ),
                      boxShadow: isDarkMode ? [] : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: book.imageUrl != null && book.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: ApiService.getFullImageUrl(book.imageUrl!),
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(color: primaryColor),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.book_outlined,
                                size: 48,
                                color: textColor.withOpacity(0.3),
                              ),
                            )
                          : Icon(
                              Icons.book_outlined,
                              size: 48,
                              color: textColor.withOpacity(0.3),
                            ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Detail labels and buttons
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailText('Муаллиф', book.author, textColor),
                        const SizedBox(height: 8),
                        _buildDetailText('Категория', book.categoryName, textColor),
                        const SizedBox(height: 8),
                        _buildDetailText('Рейтинг', rating, textColor),
                        const SizedBox(height: 8),
                        
                        // Pricing
                        Row(
                          children: [
                            Text(
                              'Нарх: ',
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${book.price.toStringAsFixed(0)} TJS',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Action button(s)
                        if (canBuy && onAddToCart != null)
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: () {
                                onAddToCart!();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('"${book.title}" ба сабад илова шуд'),
                                    backgroundColor: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E7431),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Ба сабад',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        if (canRead) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => EbookReaderScreen(book: book)),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF1E7431), width: 1.5),
                                foregroundColor: const Color(0xFF1E7431),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Хондан',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E7431),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (!canBuy && !canRead)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Тамом шуд',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Description Title
              Text(
                'Тавсиф:',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Description Content
              Text(
                book.description ?? 'Тафсилоти китоб вуҷуд надорад.',
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailText(String label, String value, Color textColor) {
    return RichText(
      text: TextSpan(
        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 15),
        children: [
          TextSpan(text: '$label : '),
          TextSpan(
            text: value,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
