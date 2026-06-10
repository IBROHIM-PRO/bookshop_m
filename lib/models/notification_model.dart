class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final String category;
  final bool isRead;
  final DateTime dateCreated;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.category,
    required this.isRead,
    required this.dateCreated,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    var dateStr = json['dateCreated'] as String?;
    DateTime dt;
    if (dateStr != null) {
      if (!dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains('-')) {
        dateStr = '${dateStr}Z';
      }
      dt = DateTime.parse(dateStr).toLocal();
    } else {
      dt = DateTime.now();
    }
    return NotificationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'General',
      category: json['category'] ?? 'Academic',
      isRead: json['isRead'] ?? false,
      dateCreated: dt,
    );
  }
}
