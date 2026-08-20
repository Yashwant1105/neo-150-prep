# Neo 150 Prep

A Flutter + Riverpod + Supabase mobile app for completing NeetCode 150 as a satisfying daily coding grind.

## What is included

- Dark developer/gaming visual system
- All 150 seeded problems in `assets/data/neetcode150.json`
- Home progress loop
- Problem library with search, topic/difficulty/status filters and sorting
- Problem detail with LeetCode link, completion, notes and review flag
- XP + level calculation
- Streak calculation
- Progress by difficulty/topic + activity heatmap
- Daily goal selector
- Local persistence for offline-first progress
- Supabase progress sync when authenticated
- Google OAuth hook through Supabase
- Supabase RLS schema + seeded problem/achievement data
- JSON export payload preparation

## Run locally

1. Install Flutter 3.24+.
2. Create a Supabase project.
3. Run `supabase/schema.sql` in the Supabase SQL editor.
4. Configure Google OAuth in Supabase Auth.
5. Configure mobile deep link `io.minsprep://login-callback` for Android/iOS.
6. Run:

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Never put the Supabase service-role key in the app. The client only needs the anon/publishable key.

## Auth note

The app uses Supabase OAuth with Google. Before App Store submission, add Sign in with Apple alongside Google to satisfy Apple's third-party login requirements where applicable.

## Dataset verification

See `DATA_VERIFICATION.md`. The seed is intentionally local so the library remains available offline.

## Phase 2 production additions

The architecture is ready for:
- local push notification scheduling for the 8 PM streak-risk reminder
- richer achievement unlock animations
- focus mode timer
- offline mutation queue with retry metadata
- complete native JSON file/share export
- user profile trigger + user_stats server-side aggregation
- conflict timestamps for stricter sync reconciliation
