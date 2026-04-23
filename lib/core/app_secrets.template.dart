// Template for the Firebase project identifiers used by the secondary
// FirebaseApp (member creation flow) and the FCM send endpoint.
//
// Setup:
//   1. Copy this file to `lib/core/app_secrets.dart` (same folder).
//   2. Fill in the values below from:
//        Firebase Console -> Project settings -> General ->
//        Your apps -> Android app.
//   3. `app_secrets.dart` is gitignored; keep it out of version control.
//
// The app will not compile without `app_secrets.dart` in place.

class AppSecrets {
  static const firebaseProjectId = 'your-project-id';
  static const firebaseApiKey = 'YOUR_ANDROID_API_KEY';
  static const firebaseAppId = '1:000000000000:android:0000000000000000000000';
  static const firebaseMessagingSenderId = '000000000000';
  static const firebaseStorageBucket = 'your-project-id.firebasestorage.app';
}
