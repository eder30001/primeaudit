---
generated: 2026-04-16
focus: tech
---

# Technology Stack

## Languages

**Primary:**
- Dart `>=3.11.4 <4.0.0` - All application logic (`primeaudit/lib/`)
- SQL (PostgreSQL dialect) - Database migrations (`primeaudit/supabase/migrations/`, `primeaudit/lib/supabase/migrations/`)

**Secondary:**
- Kotlin (Android host shell) - `primeaudit/android/app/src/main/kotlin/com/example/primeaudit/`
- XML - Android manifest and resources (`primeaudit/android/app/src/main/`)

## Runtime

**Environment:**
- Flutter `>=3.38.4` (locked in `pubspec.lock`)
- Dart SDK `>=3.11.4 <4.0.0`

**Package Manager:**
- `pub` (Flutter's built-in package manager)
- Lockfile: `primeaudit/pubspec.lock` — present and committed

## Frameworks

**Core:**
- `flutter` SDK — Cross-platform UI framework; Material 3 design system enabled (`uses-material-design: true` in `pubspec.yaml`)

**State Management:**
- `ValueNotifier<ThemeMode>` (global `appThemeMode` in `primeaudit/lib/main.dart`) — lightweight reactive state for theme switching
- `StreamBuilder<AuthState>` — drives the authentication gate in `primeaudit/lib/main.dart`
- No third-party state management library (no Riverpod, BLoC, Provider, etc.)

**Testing:**
- `flutter_test` SDK — standard Flutter test framework
- No additional test packages declared

**Build/Dev:**
- `flutter_lints` `^6.0.0` (resolved `6.0.0`) — lint ruleset extending `package:flutter_lints/flutter.yaml`
- Gradle `8.14` (Android build system, `primeaudit/android/gradle/wrapper/gradle-wrapper.properties`)
- Java 17 compile target (`primeaudit/android/app/build.gradle.kts`)
- Dart DevTools — `primeaudit/devtools_options.yaml` present

## Key Dependencies

**Direct (production):**

| Package | Resolved Version | Purpose |
|---------|-----------------|---------|
| `supabase_flutter` | `2.12.2` | Primary backend SDK — auth, database, storage, realtime |
| `shared_preferences` | `2.5.5` | Local persistence for theme, settings, and company context |
| `cupertino_icons` | `1.0.9` | iOS-style icon set for Material widgets |

**Transitive (notable):**

| Package | Resolved Version | Role |
|---------|-----------------|------|
| `supabase` | `2.10.4` | Core Supabase Dart client (wrapped by `supabase_flutter`) |
| `postgrest` | `2.6.0` | PostgREST query builder — all database calls use this |
| `gotrue` | `2.19.0` | Supabase Auth client (email/password, session management) |
| `realtime_client` | `2.7.1` | Supabase Realtime (WebSocket subscriptions) |
| `storage_client` | `2.5.1` | Supabase Storage client (included but not actively used in app code) |
| `functions_client` | `2.5.0` | Supabase Edge Functions client (included but not actively used in app code) |
| `app_links` | `7.0.0` | Deep link / OAuth redirect handling (required by `supabase_flutter`) |
| `dart_jsonwebtoken` | `3.4.0` | JWT parsing for Supabase tokens |
| `http` | `1.6.0` | HTTP client used internally by Supabase packages |
| `web_socket_channel` | `3.0.3` | WebSocket support for Realtime |
| `rxdart` | `0.28.0` | Reactive streams (used internally by Supabase packages) |
| `url_launcher` | `6.3.2` | Opens external URLs (OAuth, magic links) |
| `path_provider` | `2.1.5` | File system path access |
| `pointycastle` | `4.0.0` | Cryptographic primitives for JWT handling |

## Configuration

**Environment:**
- Supabase URL and anon key are hardcoded as Dart constants in `primeaudit/lib/core/supabase_config.dart`
- No `.env` file — credentials are compiled into the binary (anon key is designed to be public per Supabase's model)
- Theme preference stored under key `settings_theme` in `SharedPreferences`
- Company context for superuser/dev roles stored under keys `ctx_company_id` / `ctx_company_name` in `SharedPreferences`

**Build:**
- `primeaudit/pubspec.yaml` — Flutter package manifest
- `primeaudit/analysis_options.yaml` — Dart static analysis config
- `primeaudit/android/app/build.gradle.kts` — Android Gradle config
- `primeaudit/android/build.gradle.kts` — Android root Gradle config

## Platform Targets

**Mobile (primary):**
- Android: `primeaudit/android/` — Gradle 8.14, Java 17, `compileSdk` from Flutter defaults
- iOS: `primeaudit/ios/` — Xcode project present

**Other (scaffolded, not primary):**
- `primeaudit/macos/`, `primeaudit/web/` — Flutter scaffold directories present; no custom platform code

**Development:**
- Flutter `>=3.38.4` and Dart `>=3.11.4` required
- Android Studio or VS Code with Dart/Flutter extensions

---

*Stack analysis: 2026-04-16*
