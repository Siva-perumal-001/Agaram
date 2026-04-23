import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/kural.dart';

class KuralService {
  static List<Kural>? _bundled;

  static Future<List<Kural>> _loadBundle() async {
    if (_bundled != null) return _bundled!;
    final raw = await rootBundle.loadString('assets/kurals.json');
    final list = (jsonDecode(raw) as List)
        .map((e) => Kural.fromJson(e as Map<String, dynamic>))
        .toList();
    _bundled = list;
    return list;
  }

  static String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static Future<Kural> todaysKural() async {
    final bundled = await _loadBundle();
    final now = DateTime.now();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('kurals')
          .doc(_dateKey(now))
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return Kural(
          number: (data['number'] as num?)?.toInt() ?? 0,
          tamil: data['tamil'] as String? ?? '',
          english: data['english'] as String? ?? '',
          chapter: data['chapter'] as String? ?? '',
        );
      }
    } catch (_) {
      // Offline / permission — fall back to bundled rotation.
    }
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    return bundled[dayOfYear % bundled.length];
  }
}
