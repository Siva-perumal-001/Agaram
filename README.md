# Agaram — Tamil Ilakiya Mandram App

Flutter Android app for the college Tamil Literature club. Built on Firebase Spark (free) + Cloudinary (free).

## Quick start

1. Follow **[SETUP.md](SETUP.md)** for Firebase config (one-time, ~10 min).
2. `flutter pub get`
3. `flutter run`

## Project structure

```
lib/
├── main.dart                       App entry, Firebase init
├── app.dart                        MaterialApp + routes
├── core/
│   ├── theme.dart                  Colors, typography, M3 theme
│   ├── auth_service.dart           Sign in / reset / sign out
│   └── routes.dart                 Route name constants
├── models/
│   └── app_user.dart               User model
├── screens/
│   ├── auth/
│   │   ├── splash_screen.dart
│   │   ├── login_screen.dart
│   │   └── forgot_password_screen.dart
│   └── placeholders.dart           Admin/Member home stubs (Phase 2)
└── widgets/
    └── agaram_logo.dart            "அ AGARAM" wordmark
```

## Build phases

- [x] **Phase 1** — Foundation & Auth (Splash, Login, Forgot Password)
- [x] **Phase 2** — Home, Profile, Events list, Kural of the Day, Monthly theme banner, bottom nav
- [x] **Phase 3** — Events & Tasks: event CRUD, banner upload (Cloudinary), task assign + proof upload (image/PDF), admin review queue with approve/reject, auto-award stars on approval
- [x] **Phase 4** — Attendance via rotating QR (admin shows, member scans, +2 stars tx) + Event gallery grid + photo lightbox + admin manual mark
- [ ] **Phase 5** — Notifications, Members, Leaderboard
- [ ] **Phase 6** — Polish & APK release

Full plan: `/Users/apple/.claude/plans/tamil-club-app-replicated-hedgehog.md`
