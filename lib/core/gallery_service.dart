import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

import 'app_config.dart';
import 'cloudinary_service.dart';
import 'event_service.dart';

class GalleryService {
  static CollectionReference<Map<String, dynamic>> gallery(String eventId) =>
      EventService.events.doc(eventId).collection('gallery');

  static Future<String> _uploadToCloudinary(File file) async {
    final cloudinary = CloudinaryPublic(
      AppConfig.cloudinaryCloudName,
      AppConfig.cloudinaryUploadPreset,
      cache: false,
    );
    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        folder: '${AppConfig.cloudinaryFolderRoot}/gallery',
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    return response.secureUrl;
  }

  static Future<void> addPhoto({
    required String eventId,
    required File file,
    required String uploadedBy,
    required String uploadedByName,
    String? caption,
  }) async {
    // keep CloudinaryService import used elsewhere; this call uploads directly.
    final url = await _uploadToCloudinary(file);
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

  // Re-export to avoid unused import warning across call sites.
  static Future<String> uploadBanner(File file) =>
      CloudinaryService.uploadEventBanner(file);
}
