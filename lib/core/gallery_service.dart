import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'cloudinary_service.dart';
import 'event_service.dart';

class GalleryService {
  static CollectionReference<Map<String, dynamic>> gallery(String eventId) =>
      EventService.events.doc(eventId).collection('gallery');

  static Future<void> addPhoto({
    required String eventId,
    required File file,
    required String uploadedBy,
    required String uploadedByName,
    String? caption,
  }) async {
    final url = await CloudinaryService.uploadGalleryPhoto(file, eventId: eventId);
    await gallery(eventId).add({
      'url': url,
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'uploadedAt': FieldValue.serverTimestamp(),
      'caption': caption,
    });
  }

  static Future<void> deletePhoto({
    required String eventId,
    required String photoId,
  }) {
    return gallery(eventId).doc(photoId).delete();
  }

  // Convenience re-export so event form screen doesn't need to import
  // CloudinaryService directly.
  static Future<String> uploadBanner(File file) =>
      CloudinaryService.uploadEventBanner(file);
}
