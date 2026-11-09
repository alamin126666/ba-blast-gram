// Dart interface to the native API key store.
//
// The owner's api_id/api_hash live obfuscated in native code
// (android/app/src/main/cpp/telegram_keys.cpp and
// ios/Runner/telegram_keys.c) and are decrypted only at runtime in
// native code. Dart reaches them through dart:ffi on mobile/desktop.
// On web (no dart:ffi) the stub is used and the keys read as "not
// configured" — real Telegram login is not supported on web anyway.
export 'telegram_keys_stub.dart'
    if (dart.library.ffi) 'telegram_keys_ffi.dart';
