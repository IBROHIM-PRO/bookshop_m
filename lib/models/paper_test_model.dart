class PaperTestResultModel {
  final int id;
  final String studentName;
  final String subject;
  final int score;
  final int? studentId;
  final DateTime dateCreated;

  PaperTestResultModel({
    required this.id,
    required this.studentName,
    required this.subject,
    required this.score,
    this.studentId,
    required this.dateCreated,
  });

  factory PaperTestResultModel.fromJson(Map<String, dynamic> json) {
    return PaperTestResultModel(
      id: json['id'],
      studentName: json['studentName'] ?? '',
      subject: json['subject'] ?? '',
      score: json['score'] ?? 0,
      studentId: json['studentId'],
      dateCreated: DateTime.parse(json['dateCreated']),
    );
  }
}
