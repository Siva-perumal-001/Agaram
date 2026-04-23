class Kural {
  final int number;
  final String tamil;
  final String english;
  final String chapter;

  const Kural({
    required this.number,
    required this.tamil,
    required this.english,
    required this.chapter,
  });

  factory Kural.fromJson(Map<String, dynamic> json) {
    return Kural(
      number: (json['number'] as num).toInt(),
      tamil: json['tamil'] as String,
      english: json['english'] as String,
      chapter: json['chapter'] as String? ?? '',
    );
  }
}
