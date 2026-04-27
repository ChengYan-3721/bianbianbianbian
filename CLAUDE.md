# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

This is a **Flutter 3.x bookkeeping app** (`bianbianbianbian` / 边边记账 / 边编边变). The repo currently contains only the default Flutter scaffold (counter demo in `lib/main.dart`). **Feature implementation has not started.** The authoritative product spec is `design-document.md` at the repo root — treat it as the source of truth for product decisions before writing code.

## Commands

Run from the repo root. On this Windows machine the shell is bash, so use forward slashes and `/dev/null` (not `NUL`).

| Task | Command |
| :-- | :-- |
| Install deps | `flutter pub get` |
| Run app (dev) | `flutter run` (choose device when prompted) |
| Static analysis | `flutter analyze` |
| All tests | `flutter test` |
| Single test | `flutter test test/widget_test.dart --plain-name "<test name>"` |
| Release APK | `flutter build apk --release` |
| Release iOS | `flutter build ipa` (macOS only) |
| Format | `dart format lib test` |

Dart SDK constraint: `^3.11.5` (see `pubspec.yaml`). Lints come from `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`.

## Architectural Plan (from design-document.md)

The design doc already commits to these choices — align new code with them rather than inventing alternatives:

- **Offline-first**: local SQLite is the single source of truth; cloud sync is optional.
- **State management**: Riverpod 2.x.
- **Local DB**: `drift` + `sqlcipher_flutter_libs` (encrypted SQLite; key stored in platform Keystore/Keychain via `flutter_secure_storage`).
- **Remote**: `supabase_flutter`. Two modes coexist:
  1. Official hosted Supabase (we run it).
  2. User-supplied `SUPABASE_URL` + `ANON_KEY` (BYO instance, BeeCount-style).
- **Auth UX**: no phone/social registration. Users create "同步凭证" (email + password, framed as a credential, not an account) or paste an exported "同步码" to restore on a new device.
- **Sync model**: local write queue → batched push → pull since `last_sync_at` → merge. Every row carries `id (uuid)`, `updated_at`, `deleted_at` (soft delete), `device_id`, `content_hash`. Conflict rule: last-write-wins, tie-break by `device_id` lex order, surface a conflict copy for manual review.
- **Encryption at rest and in transit**: sensitive fields (`note`, `attachments`) are AES-256-GCM encrypted on-device with a PBKDF2-derived key before upload to Supabase. The derived key **never leaves the device**.
- **Trash**: all deletes are soft; hard-delete after 30 days on device + via cloud sweep.

### Suggested `lib/` layout (not yet created)
```
lib/
├─ app/          routing, theme, i18n
├─ core/         crypto, network (Supabase client), utils
├─ data/         local (drift DAOs), remote (Supabase data sources), repositories
├─ domain/       entities + use cases
├─ features/    record / stats / ledger / budget / account / sync / trash / lock / import_export / settings
└─ main.dart
```

### Data model anchors
Primary local tables: `ledger`, `category`, `account`, `transaction_entry`, `budget`, `sync_op` (outbound queue), `user_pref`. Schema DDL is in `design-document.md` §7.1 — use it verbatim when setting up drift.

## Working Conventions

- **Prefer editing existing files** over creating new ones; the scaffold `lib/main.dart` should be replaced, not left alongside new entry points.
- **Do not regress the offline-first invariant**: any new feature must work with the network off.
- **UI direction is "温馨可爱风" (warm/cute, like 叨叨记账)**, not a professional fintech look. Palette and component rules live in `design-document.md` §10.
- **Reference product**: <https://github.com/TNT-Likely/BeeCount> — consult when designing the Supabase schema, RLS policies, or sync queue; our version layers official-hosted mode and field-level encryption on top.


# IMPORTANT:
# Always read memory-bank/@architecture.md before writing any code. Include entire database schema.
# Always read memory-bank/@design-document.md before writing any code.
# After adding a major feature or completing a milestone, update memory-bank/@architecture.md.