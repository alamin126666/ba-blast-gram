// Web / non-FFI build of the native key store.
//
// dart:ffi is unavailable here, so there is no native library to read.
// The keys always read as "not configured", which makes login fail
// loudly with "API keys not configured — owner must add api_id/api_hash"
// instead of silently falling back to anything else.
class TelegramKeys {
  const TelegramKeys._();

  /// The owner's api_id, or 0 when not configured.
  static int get nativeApiId => 0;

  /// The owner's api_hash, or '' when not configured.
  static String get nativeApiHash => '';

  /// True only when the owner's keys are present in the native store.
  static bool get isConfigured => false;
}
