# Firestore Rules Tests

Automated security-rules regression tests for Agaram. The suite boots the
Firebase Firestore emulator locally, loads `../../firestore.rules`, and
asserts every allow/deny path across the 9 collections (users, events,
tasks, attendance, gallery, wallet, notifications, kurals, themes) plus
the `collectionGroup('tasks')` read path.

## Run

```bash
cd tool/firestore-tests
npm install          # first time only
npm test
```

Takes ~35 seconds. The emulator auto-starts and auto-shuts down. Exits
non-zero on any rule regression, so you can wire it into CI as-is.

## What it covers (80 cases)

- **FND-02** — user self-update allowlist (stars / email / joinedAt locked)
- **FND-03** — task review metadata is admin-only
- **FND-04** — attendance requires `qrSecretUsed` matching event secret
- **FND-18** — gallery / wallet pin `uploadedBy` + Cloudinary URL
- Plus every un-named allow/deny path — role / president / unauth /
  cross-tenant scenarios for every collection.

## Adding a new rule? Add a test.

Open `rules.test.js`, find the right `describe` block, add an `it(...)`
with a fresh context (`memberDb()`, `adminDb()`, etc.) and
`assertSucceeds` / `assertFails`. Seed any pre-state inside
`testEnv.withSecurityRulesDisabled(...)` so rules don't block setup.

## Troubleshooting

- **Port 8080 already in use** → kill whatever's on it, or add
  `"emulators.firestore.port": 8081` in `../../firebase.json`.
- **`@firebase/rules-unit-testing` peer error** → make sure
  `package.json` pins `firebase` to `^11.0.0`; v12 is not supported yet.
- **Emulator boots but every test times out** → Java missing; install
  Temurin 21 and ensure `java --version` works.
