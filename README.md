# BA BLAST GRAM

A premium Telegram client built with **Flutter & Dart** — Telegram's design,
our premium UI/UX and smooth animations, and the **real Telegram API**
(MTProto) under the hood.

- **App name:** BA BLAST GRAM (`com.ba.blastgram`)
- **Real Telegram only.** Every chat, message and contact comes from the
  real Telegram API — no fake content of any kind. If there is no login
  yet, the app shows only login/onboarding, never invented chats.
- **One API credential — the owner's.** The owner's `api_id` / `api_hash`
  are stored encrypted in the native library (see "Going Live"). End
  users never enter keys; they log in with their own phone number + the
  OTP Telegram sends them.

## What works

| Area | Status |
| --- | --- |
| Splash + onboarding with smooth animations | ✅ |
| Phone → OTP → 2FA login via real MTProto (`mtflute` 0.2.9, API layer 228) | ✅ |
| Session resume (login survives restarts) | ✅ |
| Chat list: folders (All / Personal / Groups / Channels / Unread), search, stories row, swipe to pin/delete, unread badges, verified/muted marks | ✅ |
| Chat screen: bubbles, replies, forwards, reactions (local), copy, delete (revoke, on Telegram), emoji picker, attach menu, voice-recorder UI | ✅ |
| Live incoming messages (MTProto updates push) | ✅ |
| Contacts (from your Telegram dialogs), New Group / New Channel flows | ✅ |
| Saved Messages, Settings, profile editing (local), chat info, global search | ✅ |
| Dark + light premium themes (Telegram blue → violet gradient) | ✅ |
| Stories viewer UI (progress + tap navigation) | ✅ UI, sync pending (see below) |
| Voice/video call UI | ✅ UI only (see below) |

## Run it (development)

```sh
flutter pub get
flutter run
```

Requirements: Flutter 3.35+ (verified with Flutter 3.47.9 / Dart 3.13.7).
No Android SDK is needed for `flutter analyze`, `flutter test` or
`flutter build web`. Building an APK needs the Android SDK + Java 17
and the Android NDK (the native key store is built with CMake).

## Going Live — the owner's API keys (do this BEFORE the final build)

The app cannot log in until the owner's Telegram API credentials are
in the encrypted native store. The owner does this **once**:

1. Go to <https://my.telegram.org> and log in with the **owner's**
   Telegram phone number.
2. Open **API development tools** and create an app (any name/platform).
3. Copy the `api_id` (a number) and `api_hash` (a string).
4. Give them to the builder through the **secure flow — never in plain
   chat, never committed to the repo**.
5. The builder generates the obfuscated native block:

```sh
dart scripts/make_keys.dart 123456 abcdef0123456789abcdef0123456789
```

6. The builder pastes the printed block into **both** native files,
   replacing the `OWNER PLACEHOLDER` block:
   - `android/app/src/main/cpp/telegram_keys.cpp` (Android NDK, CMake)
   - `ios/Runner/telegram_keys.c` (Xcode, Runner target)
7. Then build normally — no keys on the command line, ever:

```sh
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

Or use the script (it refuses to build while the placeholders are
still in place):

```sh
scripts/build_with_credentials.sh apk
```

How the keys are stored:

- The keys live as XOR-obfuscated bytes in the native C/C++ files
  above and are decrypted **only at runtime in native code**. Dart
  reads them through `dart:ffi` via `lib/config/telegram_keys.dart`
  (`TelegramKeys.nativeApiId` / `TelegramKeys.nativeApiHash`).
- The keys are never in plain Dart code, pubspec, `strings.xml`, or
  plain text anywhere in the repository.
- Obfuscation is not real encryption — anyone who can read the binary
  and the XOR key can recover the values. That is the normal trade-off
  for every Telegram client (official clients embed theirs too).
- End users are never asked for keys. The login screen only ever asks
  for a phone number, then the OTP, then the 2FA password if the
  account has one.

Without keys the app still builds and runs, but the login screen shows
"API keys not configured — owner must add api_id/api_hash" and the
Continue button is disabled.

## Build outputs

```sh
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
flutter build web   # compiles; real Telegram login is NOT supported on web
                    # (mtflute is dart:io based) — use Android/iOS/desktop.
```

## Architecture

```
lib/
  main.dart                 App entry + auth-aware root router
  config/
    telegram_config.dart    App name, package, api layer, key-store docs
    telegram_keys.dart      Dart interface to the native key store
                            (TelegramKeys.nativeApiId / nativeApiHash)
    telegram_keys_ffi.dart  dart:ffi implementation (mobile/desktop)
    telegram_keys_stub.dart Web build (always "not configured")
    app_theme.dart          Premium light/dark themes, brand gradient
  models/models.dart        Chat, ChatMessage, Contact, Story, CallRecord…
  services/
    telegram_api_service.dart   The one interface the UI talks to
    live_telegram_service_io.dart   Real MTProto via mtflute (mobile/desktop)
    live_telegram_service_stub.dart Web stub (clear error, keeps web building)
  state/app_state.dart      Provider state: auth, chats, messages, settings
  widgets/                  Avatar/logo, chat tile, message bubble, stories
  screens/                  Splash/onboarding/login, home, chat, contacts,
                            calls, stories viewer, settings/profile/search
android/app/src/main/cpp/
  telegram_keys.cpp         Owner's obfuscated api_id/api_hash (NDK)
  CMakeLists.txt            Builds libtelegram_keys.so
ios/Runner/
  telegram_keys.c           Same native key store, compiled into Runner
scripts/
  make_keys.dart            Generates the obfuscated native block
  build_with_credentials.sh Build wrapper (refuses placeholder builds)
```

State: **Provider** (`ChangeNotifier`), one consistent choice.
Telegram layer: **mtflute 0.2.9** — pure-Dart MTProto, no native libs.
The service maps real Telegram objects to app models:

- `getDialogs` → chats (personal / group / channel / bot / Saved Messages)
- `getHistory` → messages (text, photo, voice, file, location, replies,
  forwards, reactions, edits)
- `sendMessage` / `forwardMessages` / `deleteMessages` → real sends
- `getMe` → profile, `onMessage` → live incoming messages

Why mtflute and not a TDLib Flutter binding: the `tdlib` package on
pub.dev was last updated 2023-08-13, ships a `libtdjson` binary for
Android only, and needs a manually built native library for every
other platform. TDLib itself is the official C++ library, but wiring
it needs a per-platform native build (NDK/CMake on Android, Xcode on
iOS) that cannot be verified on a machine without the Android SDK/NDK.
mtflute is a maintained pure-Dart MTProto client (API layer 228) that
resolves cleanly with current Flutter/Dart and needs no native libs —
so it is the real Telegram layer used here. Switching to TDLib later
is a service-layer swap behind `telegram_api_service.dart`.

## Known limits (honest)

- **Stories sync is not wired.** mtflute 0.2.9 exposes no stories
  helper, so the stories row is empty until that lands. The viewer UI
  is complete.
- **Voice/video calls are UI only.** Real Telegram calls need the
  TDLib native library (`libtdjson`) — a much heavier native build.
  The call screen says this instead of pretending to connect, and call
  attempts are logged locally in Calls.
- **Group/channel creation is local for now.** The conversation is
  created in the app immediately; the server-side create call is the
  next MTProto wiring step.
- **Reactions are local for now.** Tapping a reaction updates the
  bubble in the app; sending the reaction to Telegram's servers is a
  later step.
- **Profile name/bio edits are local for now.** Same reason as above.
- **Media upload (photo/file/voice/location) is not wired.** Sending
  text, replies, forwards and deletes are real; uploads need mtflute's
  file-upload calls wired to a picker.
- **No web login.** mtflute is `dart:io` based. Web builds compile and
  show splash/onboarding/login, but login throws a clear error.
  Use Android/iOS/desktop for real Telegram.
- **Native key-store build not verified on this machine.** The NDK
  build of `libtelegram_keys.so` (and the Xcode build of the iOS
  equivalent) needs the Android SDK/NDK, which this machine does not
  have. The C code is syntax-checked and the FFI interface is verified
  against a host build — the first real APK/iOS build must be done on
  a machine with the SDK/NDK installed.

## Verify

```sh
flutter pub get     # must pass, no legacy flags; pubspec.lock is committed
flutter analyze     # must pass with zero errors
flutter test        # widget smoke tests (splash → onboarding → login)
flutter build web   # compiles the app (see "No web login" above)
```

The zip handover rule applies: verify the *exact* zip in a fresh
directory with `flutter pub get` + `flutter analyze` before shipping it.

## Not affiliated with Telegram

BA BLAST GRAM is an unofficial client. It uses the official Telegram
API (MTProto) with the owner's credentials. Not affiliated with or
endorsed by Telegram.
