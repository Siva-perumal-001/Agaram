import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/monthly_theme.dart';

class MonthlyThemeService {
  static String currentYearMonth([DateTime? now]) {
    final n = now ?? DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}';
  }

  static Future<MonthlyTheme> currentTheme() async {
    final id = currentYearMonth();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('themes')
          .doc(id)
          .get();
      if (doc.exists) return MonthlyTheme.fromFirestore(doc);
    } catch (_) {
      // Offline / permission — use fallback.
    }
    return MonthlyTheme.neutralFallback();
  }
}
