class AppConfig {
  static const cloudinaryCloudName = 'dttox49ht';
  static const cloudinaryUploadPreset = 'agaram_uploads';
  static const cloudinaryFolderRoot = 'agaram';

  static const starsPerApprovedTask = 3;
  static const starsPerAttendance = 2;

  static const maxProofFileSizeMb = 10;

  // Firebase project identifiers live in lib/core/app_secrets.dart, which is
  // gitignored. See app_secrets.template.dart for the expected shape.

  // FCM topics.
  static const topicAllMembers = 'all_members';
  static const topicAdmins = 'admins_only';

  // Path to the bundled Firebase service-account JSON (admin FCM sending).
  static const fcmServiceAccountAsset = 'assets/fcm-service-account.json';
}
