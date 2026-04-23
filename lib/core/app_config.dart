class AppConfig {
  static const cloudinaryCloudName = 'dttox49ht';
  static const cloudinaryUploadPreset = 'agaram_uploads';
  static const cloudinaryFolderRoot = 'agaram';

  static const starsPerApprovedTask = 3;
  static const starsPerAttendance = 2;

  // Upload size caps enforced client-side before handing to Cloudinary.
  // Cloudinary's free plan rejects >10 MB anyway; keeping caps here lets us
  // show a friendly message instead of an opaque SDK error.
  static const maxProofFileSizeMb = 10;
  static const maxGalleryFileSizeMb = 10;
  static const maxWalletFileSizeMb = 10;
  static const maxBannerFileSizeMb = 5;
  static const maxAvatarFileSizeMb = 3;

  // Firebase project identifiers live in lib/core/app_secrets.dart, which is
  // gitignored. See app_secrets.template.dart for the expected shape.

  // FCM topics.
  static const topicAllMembers = 'all_members';
  static const topicAdmins = 'admins_only';

  // Path to the bundled Firebase service-account JSON (admin FCM sending).
  static const fcmServiceAccountAsset = 'assets/fcm-service-account.json';
}
