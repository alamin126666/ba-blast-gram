// Telegram API configuration for BA BLAST GRAM — real Telegram only.
//
// Credential model (as the owner specified):
// * ONE api_id / api_hash — the owner's — is stored encrypted/obfuscated
//   in the native library and decrypted only at runtime in native code:
//       android/app/src/main/cpp/telegram_keys.cpp  (NDK, CMake)
//       ios/Runner/telegram_keys.c                  (Xcode, Runner target)
//   The Dart side reads them through dart:ffi
//   (see lib/config/telegram_keys.dart). The keys are never in plain
//   Dart code, pubspec, strings.xml, or plain text anywhere in the repo.
// * End users NEVER enter api_id/api_hash. They log in with their own
//   phone number + the OTP Telegram sends them.
// * Until the owner supplies keys, [isConfigured] is false and login
//   fails loudly with [notConfiguredMessage] — there is no fallback,
//   no fake content, no invented chats.
//
// How the owner enables real Telegram (once, before the final build):
//   1. Go to my.telegram.org, log in with the owner's Telegram number.
//   2. Open "API development tools" and create an app.
//   3. Copy the api_id and api_hash.
//   4. Give them to the builder through the secure flow (never plain chat).
//   5. The builder runs `dart scripts/make_keys.dart <id> <hash>` and
//      pastes the output into the two native files above, replacing the
//      OWNER PLACEHOLDER block, then rebuilds.

import 'telegram_keys.dart';

class TelegramConfig {
  const TelegramConfig._();

  /// The owner's api_id, read from the encrypted native store.
  /// 0 = not configured yet.
  static int get apiId => TelegramKeys.nativeApiId;

  /// The owner's api_hash, read from the encrypted native store.
  /// '' = not configured yet.
  static String get apiHash => TelegramKeys.nativeApiHash;

  /// The app's display name. Never use "Telegram" as the app name.
  static const String appName = 'BA BLAST GRAM';

  /// Android application id / iOS bundle id.
  static const String packageName = 'com.ba.blastgram';

  /// Telegram API layer targeted by the bundled MTProto client (mtflute).
  static const int apiLayer = 228;

  /// True only when the owner's keys are present in the native store.
  static bool get isConfigured => TelegramKeys.isConfigured;

  /// The loud failure shown at login while the keys are missing.
  static const String notConfiguredMessage =
      'API keys not configured — owner must add api_id/api_hash';

  static const String myTelegramUrl = 'https://my.telegram.org';

  static const String liveSetupSteps = '''
How the owner enables real Telegram (once, before the final build):
1. Go to my.telegram.org and log in with the owner's Telegram phone number.
2. Open "API development tools" and create an app.
3. Copy the api_id and api_hash.
4. Give them to the builder through the secure flow (never in plain chat).
5. The builder runs: dart scripts/make_keys.dart <api_id> <api_hash>
   and pastes the output into android/app/src/main/cpp/telegram_keys.cpp
   and ios/Runner/telegram_keys.c, replacing the OWNER PLACEHOLDER block.
6. Rebuild the app.
End users then just log in with their own phone number + OTP — they
never see or enter api_id/api_hash.
''';
}
