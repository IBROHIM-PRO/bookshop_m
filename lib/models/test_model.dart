class TestModel {
  final int id;
  final String title;
  final String? description;
  final int? bookId;
  final String? bookTitle;
  final int questionCount;
  final List<QuestionModel> questions;

  TestModel({
    required this.id,
    required this.title,
    this.description,
    this.bookId,
    this.bookTitle,
    required this.questionCount,
    required this.questions,
  });

  factory TestModel.fromJson(Map<String, dynamic> json) {
    var questionsList = <QuestionModel>[];
    if (json['questions'] != null) {
      questionsList = (json['questions'] as List)
          .map((i) => QuestionModel.fromJson(i))
          .toList();
    }
    return TestModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      bookId: json['bookId'],
      bookTitle: json['bookTitle'],
      questionCount: json['questionCount'] ?? questionsList.length,
      questions: questionsList,
    );
  }
}

class QuestionModel {
  final int id;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String questionType; // 'Single', 'Multiple', 'Closed', 'TrueFalse'
  final int points;
  final String? imageUrl;

  QuestionModel({
    required this.id,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.questionType,
    required this.points,
    this.imageUrl,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] ?? 0,
      questionText: json['questionText'] ?? '',
      optionA: json['optionA'] ?? '',
      optionB: json['optionB'] ?? '',
      optionC: json['optionC'] ?? '',
      optionD: json['optionD'] ?? '',
      questionType: json['questionType'] ?? 'Single',
      points: json['points'] ?? 10,
      imageUrl: json['imageUrl'],
    );
  }
}

class TestAttemptModel {
  final int id;
  final int testId;
  final String testTitle;
  final int score;
  final int totalQuestions;
  final double percentage;
  final DateTime dateTaken;
  final bool isGraded;
  final int earnedPoints;
  final int totalPoints;

  TestAttemptModel({
    required this.id,
    required this.testId,
    required this.testTitle,
    required this.score,
    required this.totalQuestions,
    required this.percentage,
    required this.dateTaken,
    required this.isGraded,
    required this.earnedPoints,
    required this.totalPoints,
  });

  factory TestAttemptModel.fromJson(Map<String, dynamic> json) {
    return TestAttemptModel(
      id: json['id'] ?? 0,
      testId: json['testId'] ?? 0,
      testTitle: json['testTitle'] ?? '',
      score: json['score'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      dateTaken: DateTime.parse(json['dateTaken'] ?? DateTime.now().toIso8601String()),
      isGraded: json['isGraded'] ?? true,
      earnedPoints: json['earnedPoints'] ?? 0,
      totalPoints: json['totalPoints'] ?? 0,
    );
  }
}
