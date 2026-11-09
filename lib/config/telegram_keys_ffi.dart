import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

/// Native key store implementation, reached through dart:ffi.
///
/// Android loads `libtelegram_keys.so` (built by the NDK from
/// android/app/src/main/cpp/telegram_keys.cpp via CMake). iOS/macOS read
/// the symbols from the app binary itself
/// (ios/Runner/telegram_keys.c, compiled into the Runner target).
///
/// The native functions decrypt the obfuscated values at runtime and
/// return them; Dart never sees the obfuscated bytes. If the library
/// or symbols are missing (e.g. placeholders still in place, or a
/// platform without the native file), the keys read as "not configured"
/// (0 / '') and login fails loudly instead of guessing.
class TelegramKeys {
  const TelegramKeys._();

  static int? _apiId;
  static String? _apiHash;

  /// The owner's api_id, or 0 when not configured.
  static int get nativeApiId {
    _ensureLoaded();
    return _apiId ?? 0;
  }

  /// The owner's api_hash, or '' when not configured.
  static String get nativeApiHash {
    _ensureLoaded();
    return _apiHash ?? '';
  }

  /// True only when the owner's keys are present in the native store.
  static bool get isConfigured => nativeApiId != 0 && nativeApiHash.isNotEmpty;

  static void _ensureLoaded() {
    if (_apiId != null) return;
    _apiId = 0;
    _apiHash = '';
    try {
      final library = _openLibrary();
      if (library == null) return;
      final apiIdFn = library.lookupFunction<
          ffi.Int64 Function(),
          int Function()>('blastgram_api_id');
      final apiHashFn = library.lookupFunction<
          ffi.Pointer<ffi.Uint8> Function(),
          ffi.Pointer<ffi.Uint8> Function()>('blastgram_api_hash');
      _apiId = apiIdFn();
      _apiHash = _readCString(apiHashFn());
    } catch (_) {
      // Missing library/symbols = not configured. Never throw here;
      // the login screen reports the state.
      _apiId = 0;
      _apiHash = '';
    }
  }

  static ffi.DynamicLibrary? _openLibrary() {
    if (Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libtelegram_keys.so');
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return ffi.DynamicLibrary.process();
    }
    return null;
  }

  static String _readCString(ffi.Pointer<ffi.Uint8> pointer) {
    if (pointer.address == 0) return '';
    final bytes = <int>[];
    var i = 0;
    while (i < 512) {
      final byte = pointer[i];
      if (byte == 0) break;
      bytes.add(byte);
      i++;
    }
    return utf8.decode(bytes);
  }
}
