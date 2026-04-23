import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyTheme {
  final String yearMonth;
  final String tamilTitle;
  final String englishTitle;
  final String? description;

  const MonthlyTheme({
    required this.yearMonth,
    required this.tamilTitle,
    required this.englishTitle,
    this.description,
  });

  factory MonthlyTheme.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MonthlyTheme(
      yearMonth: doc.id,
      tamilTitle: data['tamilTitle'] as String? ?? '',
      englishTitle: data['englishTitle'] as String? ?? data['title'] as String? ?? '',
      description: data['description'] as String?,
    );
  }

  static const MonthlyTheme fallbackApril2026 = MonthlyTheme(
    yearMonth: '2026-04',
    tamilTitle: 'இயற்கை',
    englishTitle: 'Nature in Tamil Poetry',
    description: 'Verses that celebrate rivers, hills, monsoon, and the living world.',
  );
}
