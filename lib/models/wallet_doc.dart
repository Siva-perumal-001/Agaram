import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletDocType { pdf, image }

WalletDocType parseWalletDocType(String? raw) {
  switch (raw) {
    case 'image':
      return WalletDocType.image;
    case 'pdf':
    default:
      return WalletDocType.pdf;
  }
}

String walletDocTypeToString(WalletDocType t) =>
    t == WalletDocType.image ? 'image' : 'pdf';

class WalletDoc {
  final String id;
  final String eventId;
  final String eventTitle;
  final String title;
  final String? caption;
  final String url;
  final WalletDocType type;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime? uploadedAt;
  final int? sizeBytes;
  final String? fileName;

  const WalletDoc({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.title,
    required this.url,
    required this.type,
    required this.uploadedBy,
    required this.uploadedByName,
    this.caption,
    this.uploadedAt,
    this.sizeBytes,
    this.fileName,
  });

  String get sizeLabel {
    if (sizeBytes == null) return '';
    final mb = sizeBytes! / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    final kb = sizeBytes! / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  factory WalletDoc.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return WalletDoc(
      id: doc.id,
      eventId: data['eventId'] as String? ??
          doc.reference.parent.parent?.id ??
          '',
      eventTitle: data['eventTitle'] as String? ?? '',
      title: data['title'] as String? ?? '',
      caption: data['caption'] as String?,
      url: data['url'] as String? ?? '',
      type: parseWalletDocType(data['type'] as String?),
      uploadedBy: data['uploadedBy'] as String? ?? '',
      uploadedByName: data['uploadedByName'] as String? ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      sizeBytes: (data['sizeBytes'] as num?)?.toInt(),
      fileName: data['fileName'] as String?,
    );
  }
}
