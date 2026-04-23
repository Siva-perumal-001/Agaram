import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceMethod { qr, manual }

AttendanceMethod _parseMethod(String? raw) {
  switch (raw) {
    case 'manual':
      return AttendanceMethod.manual;
    case 'qr':
    default:
      return AttendanceMethod.qr;
  }
}

String methodToString(AttendanceMethod m) => m == AttendanceMethod.qr ? 'qr' : 'manual';

class AttendanceEntry {
  final String userId;
  final String userName;
  final DateTime? checkedInAt;
  final AttendanceMethod method;
  final int starsAwarded;

  const AttendanceEntry({
    required this.userId,
    required this.userName,
    required this.method,
    required this.starsAwarded,
    this.checkedInAt,
  });

  factory AttendanceEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AttendanceEntry(
      userId: doc.id,
      userName: data['userName'] as String? ?? '',
      checkedInAt: (data['checkedInAt'] as Timestamp?)?.toDate(),
      method: _parseMethod(data['method'] as String?),
      starsAwarded: (data['starsAwarded'] as num?)?.toInt() ?? 0,
    );
  }
}
