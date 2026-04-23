import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'cloudinary_service.dart';
import 'event_service.dart';
import '../models/wallet_doc.dart';

class WalletService {
  static CollectionReference<Map<String, dynamic>> collection(String eventId) =>
      EventService.events.doc(eventId).collection('wallet');

  static Stream<QuerySnapshot<Map<String, dynamic>>> stream(String eventId) {
    return collection(eventId)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  static Future<WalletDoc> addDoc({
    required String eventId,
    required String eventTitle,
    required File file,
    required String title,
    required WalletDocType type,
    required String uploadedBy,
    required String uploadedByName,
    String? caption,
  }) async {
    final url = await CloudinaryService.uploadWalletDoc(
      file,
      isPdf: type == WalletDocType.pdf,
    );
    final fileName = file.path.split(Platform.pathSeparator).last;
    final bytes = await file.length();

    final ref = await collection(eventId).add({
      'eventId': eventId,
      'eventTitle': eventTitle,
      'title': title,
      'caption': caption,
      'url': url,
      'type': walletDocTypeToString(type),
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'uploadedAt': FieldValue.serverTimestamp(),
      'fileName': fileName,
      'sizeBytes': bytes,
    });
    // Also bump a summary counter on the event for quick listing.
    await EventService.events.doc(eventId).set(
      {
        'walletCounts': {
          if (type == WalletDocType.pdf) 'pdfs': FieldValue.increment(1),
          if (type == WalletDocType.image) 'images': FieldValue.increment(1),
        },
        'walletLastUploadAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    final snap = await ref.get();
    return WalletDoc.fromFirestore(snap);
  }

  static Future<void> deleteDoc({
    required String eventId,
    required WalletDoc doc,
  }) async {
    await collection(eventId).doc(doc.id).delete();
    await EventService.events.doc(eventId).set(
      {
        'walletCounts': {
          if (doc.type == WalletDocType.pdf) 'pdfs': FieldValue.increment(-1),
          if (doc.type == WalletDocType.image)
            'images': FieldValue.increment(-1),
        },
      },
      SetOptions(merge: true),
    );
  }
}
