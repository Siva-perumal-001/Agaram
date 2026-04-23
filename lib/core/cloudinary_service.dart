import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';

import 'app_config.dart';

enum ProofKind { image, pdf }

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
    );
  }

  static Future<String> uploadProof(File file, {required ProofKind kind}) {
    return _upload(
      file,
      folder: '${AppConfig.cloudinaryFolderRoot}/proofs',
      resourceType: kind == ProofKind.image
          ? CloudinaryResourceType.Image
          : CloudinaryResourceType.Auto,
    );
  }

  static Future<String> _upload(
    File file, {
    required String folder,
    required CloudinaryResourceType resourceType,
  }) async {
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
