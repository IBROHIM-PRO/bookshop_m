class Book {
  final int id;
  final String title;
  final String author;
  final String? description;
  final double price;
  final int stockQuantity;
  final String? imageUrl;
  final String? pdfUrl;
  final int categoryId;
  final String categoryName;
  final String bookType; // Electronic, Printed, Both
  final String? content;

  Book({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    required this.price,
    required this.stockQuantity,
    this.imageUrl,
    this.pdfUrl,
    required this.categoryId,
    required this.categoryName,
    required this.bookType,
    this.content,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      description: json['description'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: json['stockQuantity'] ?? 0,
      imageUrl: json['imageUrl'],
      pdfUrl: json['pdfUrl'],
      categoryId: json['categoryId'] ?? 0,
      categoryName: json['categoryName'] ?? '',
      bookType: json['bookType'] ?? 'Both',
      content: json['content'],
    );
  }
}
