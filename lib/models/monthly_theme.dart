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

  /// Used when Firestore has no doc for the current month and offline
  /// fetch failed — kept neutral so it never feels stale regardless of
  /// which month the user opens the app in.
  static MonthlyTheme neutralFallback([DateTime? now]) {
    final n = now ?? DateTime.now();
    final yearMonth =
        '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}';
    return MonthlyTheme(
      yearMonth: yearMonth,
      tamilTitle: 'இம்மாத தீம்',
      englishTitle: 'Theme coming soon',
      description: 'Your club admin will publish this month\'s theme shortly.',
    );
  }
}
