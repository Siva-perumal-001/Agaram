import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';

import 'app_config.dart';

enum ProofKind { image, pdf }

class CloudinaryUploadException implements Exception {
  final String message;
  CloudinaryUploadException(this.message);
  @override
  String toString() => message;
}

class CloudinaryService {
  static final CloudinaryPublic _cloudinary = CloudinaryPublic(
    AppConfig.cloudinaryCloudName,
    AppConfig.cloudinaryUploadPreset,
    cache: false,
  );

  /// Stable, human-readable folder name for an event. Slugifies the title
  /// (lowercase ASCII + hyphens) and appends a short eventId suffix so two
  /// events with the same title don't share a folder.
  ///
  /// Examples:
  ///   ('evt_abc123def', 'Diwali Night 2026!') -> 'diwali-night-2026-evt_ab'
  ///   ('evt_abc123def', 'பொங்கல் விழா')        -> 'event-evt_ab'
  static String eventFolder({
    required String eventId,
    required String eventTitle,
  }) {
    final slug = eventTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final shortId =
        eventId.length > 8 ? eventId.substring(0, 8) : eventId;
    if (slug.isEmpty) return 'event-$shortId';
    return '$slug-$shortId';
  }

  static Future<String> uploadEventBanner(File file) {
    return _upload(
      file,
      folder: '${AppConfig.cloudinaryFolderRoot}/event-banners',
      resourceType: CloudinaryResourceType.Image,
      maxSizeMb: AppConfig.maxBannerFileSizeMb,
      kindLabel: 'banner',
    );
  }

  static Future<String> uploadProof(
    File file, {
    required ProofKind kind,
    required String eventId,
    required String eventTitle,
  }) {
    final folder = eventFolder(eventId: eventId, eventTitle: eventTitle);
    return _upload(
      file,
      folder: '${AppConfig.cloudinaryFolderRoot}/$folder/proofs',
      resourceType: kind == ProofKind.image
          ? CloudinaryResourceType.Image
          : CloudinaryResourceType.Auto,
      maxSizeMb: AppConfig.maxProofFileSizeMb,
      kindLabel: 'proof',
    );
  }

  static Future<String> uploadAvatar(File file) {
    return _upload(
      file,
      folder: '${AppConfig.cloudinaryFolderRoot}/avatars',
      resourceType: CloudinaryResourceType.Image,
      maxSizeMb: AppConfig.maxAvatarFileSizeMb,
      kindLabel: 'avatar',
    );
  }

  static Future<String> uploadWalletDoc(
    File file, {
    required bool isPdf,
    required String eventId,
    required String eventTitle,
  }) {
    final folder = eventFolder(eventId: eventId, eventTitle: eventTitle);
    return _upload(
      file,
      folder: '${AppConfig.cloudinaryFolderRoot}/$folder/wallet',
      resourceType:
          isPdf ? CloudinaryResourceType.Auto : CloudinaryResourceType.Image,
      maxSizeMb: AppConfig.maxWalletFileSizeMb,
      kindLabel: 'document',
    );
  }

  static Future<String> uploadGalleryPhoto(
    File file, {
    required String eventId,
    required String eventTitle,
  }) {
    final folder = eventFolder(eventId: eventId, eventTitle: eventTitle);
    return _upload(
      file,
      folder: '${AppConfig.cloudinaryFolderRoot}/$folder/gallery',
      resourceType: CloudinaryResourceType.Image,
      maxSizeMb: AppConfig.maxGalleryFileSizeMb,
      kindLabel: 'photo',
    );
  }

  static Future<String> _upload(
    File file, {
    required String folder,
    required CloudinaryResourceType resourceType,
    required int maxSizeMb,
    required String kindLabel,
  }) async {
    final bytes = await file.length();
    final maxBytes = maxSizeMb * 1024 * 1024;
    if (bytes > maxBytes) {
      throw CloudinaryUploadException(
        'This $kindLabel is ${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB. '
        'Please keep it under $maxSizeMb MB.',
      );
    }
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        folder: folder,
        resourceType: resourceType,
      ),
    );
    return response.secureUrl;
  }
}
