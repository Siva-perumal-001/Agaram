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

  static Future<String> uploadEventBanner(File file) {
    return _upload(
      file,
      folder: '${AppConfig.cloudinaryFolderRoot}/event-banners',
      resourceType: CloudinaryResourceType.Image,
      maxSizeMb: AppConfig.maxBannerFileSizeMb,
      kindLabel: 'banner',
    );
  }

  static Future<String> uploadProof(File file, {required ProofKind kind}) {
    return _upload(
      file,
      folder: '${AppConfig.cloudinaryFolderRoot}/proofs',
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

  static Future<String> uploadWalletDoc(File file, {required bool isPdf}) {
    return _upload(
      file,
      folder: '${AppConfig.cloudinaryFolderRoot}/wallet',
      resourceType:
          isPdf ? CloudinaryResourceType.Auto : CloudinaryResourceType.Image,
      maxSizeMb: AppConfig.maxWalletFileSizeMb,
      kindLabel: 'document',
    );
  }

  static Future<String> uploadGalleryPhoto(File file) {
    return _upload(
      file,
      folder: '${AppConfig.cloudinaryFolderRoot}/gallery',
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
