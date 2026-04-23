# Agaram — Setup Guide

Before you can run the app, you need to finish **Firebase setup** (takes ~10 minutes, free). The Flutter code is ready and waiting.

## 1. Firebase project

1. Go to https://console.firebase.google.com and click **Add project**.
2. Name it `agaram` (or anything — the name is cosmetic).
3. Disable Google Analytics when asked (not needed, keeps it simple).
4. Once the project is created, open **Project settings → General**.
5. Under "Your apps", click the **Android** icon to add an Android app.
6. Fill in:
   - **Android package name:** `com.agaram.agaram` *(must match exactly)*
   - **App nickname:** Agaram
   - **Debug signing certificate:** leave blank for now
7. Click **Register app**.
8. **Download `google-services.json`** and place it at:
   ```
   /Users/apple/Desktop/Tamil_Club/android/app/google-services.json
   ```
9. Skip the rest of the Firebase setup wizard — the gradle changes are already done.

## 2. Enable Authentication

1. In Firebase console → **Authentication → Get started**.
2. Under **Sign-in method**, enable **Email/Password** (first toggle only — don't enable the link option).

## 3. Create Firestore database

1. In Firebase console → **Firestore Database → Create database**.
2. Choose **Start in production mode** → region: **asia-south1 (Mumbai)** (closest to Tamil Nadu, free).
3. Click **Enable**.
4. Go to the **Rules** tab and paste this starter rule set (we'll tighten it in Phase 6):
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{uid} {
         allow read: if request.auth != null;
         allow write: if request.auth.uid == uid;
       }
     }
   }
   ```
5. Click **Publish**.

## 4. Create your first admin account (the president)

Since Agaram has no self-signup, you need to create the first admin manually:

1. In Firebase console → **Authentication → Users → Add user**.
2. Enter your email + a password. Click **Add user**.
3. Copy the generated **User UID** (click the copy icon next to the user row).
4. Go to **Firestore Database → Start collection**.
   - Collection ID: `users`
   - Document ID: *paste the UID you just copied*
   - Fields:
     - `name` (string) — your name
     - `email` (string) — your email
     - `role` (string) — `admin`
     - `isPresident` (boolean) — `true`
     - `stars` (number) — `0`
     - `joinedAt` (timestamp) — today
5. Click **Save**.

## 5. Run the app

```bash
cd /Users/apple/Desktop/Tamil_Club
flutter run
```

You'll see: Splash → Login. Sign in with the email + password you created in step 4. You should land on the Admin Dashboard placeholder.

## 6. Common issues

- **"Default FirebaseApp is not initialized"** → `google-services.json` is missing or in the wrong folder. Re-check step 1.8.
- **"account exists but is not set up yet"** → Firestore user doc is missing. Re-check step 4.4.
- **Stuck on splash** → check `flutter run` logs for Firebase init errors.

---

Once you're signed in and see the placeholder dashboard, tell me and I'll give you the **Phase 2 Stitch prompt** (home, profile, Kural card, theme banner).
