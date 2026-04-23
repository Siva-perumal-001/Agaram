import 'package:cloud_firestore/cloud_firestore.dart';

class GalleryPhoto {
  final String id;
  final String url;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime? uploadedAt;
  final String? caption;

  const GalleryPhoto({
    required this.id,
    required this.url,
    required this.uploadedBy,
    required this.uploadedByName,
    this.uploadedAt,
    this.caption,
  });

  factory GalleryPhoto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return GalleryPhoto(
      id: doc.id,
      url: data['url'] as String? ?? '',
      uploadedBy: data['uploadedBy'] as String? ?? '',
      uploadedByName: data['uploadedByName'] as String? ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      caption: data['caption'] as String?,
    );
  }
}
