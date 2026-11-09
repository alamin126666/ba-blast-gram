import '../config/telegram_config.dart';
import '../models/models.dart';
import 'live_telegram_service_stub.dart'
    if (dart.library.io) 'live_telegram_service_io.dart' as live;

/// The single interface every Telegram backend must implement.
///
/// BA BLAST GRAM is real Telegram only.
/// The one backend is [live.LiveTelegramService]: the real Telegram
/// MTProto client (pure-Dart `mtflute`, API layer 228) using the OWNER's
/// api_id / api_hash stored encrypted in the native library
/// (see `telegram_config.dart`).
/// End users log in with their own phone number + the OTP Telegram sends.
///
/// On mobile/desktop the mtflute implementation is used. On web the stub
/// is selected by the conditional import (mtflute is `dart:io` based and
/// has no web target) and Live calls fail with a clear message — real
/// Telegram login on web is not supported.
///
/// The UI only ever talks to this interface.
abstract class TelegramApiService {
  bool get isLoggedIn;

  /// Start the login flow for [phoneNumber] (Telegram sends an OTP).
  Future<void> sendCode(String phoneNumber);

  /// Complete login with the OTP code Telegram sent.
  /// Throws [NeedsTwoFactorAuth] when the account has 2FA enabled.
  Future<void> signInWithCode(String code);

  /// Complete login with the 2FA (cloud) password, if the account has one.
  Future<void> signInWithPassword(String password);

  Future<List<Chat>> fetchChats();
  Future<List<ChatMessage>> fetchMessages(String chatId);
  Future<ChatMessage> sendMessage(
    String chatId,
    String text, {
    String? replyToId,
  });

  /// Forward a message from one chat to another, on Telegram's servers.
  Future<void> forwardMessage({
    required String fromChatId,
    required String toChatId,
    required String messageId,
  });

  /// Delete a message for everyone (revoke), on Telegram's servers.
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  });

  /// The signed-in account's own profile, if the backend knows it.
  Future<UserProfile?> fetchMe();

  /// People the user chats with, from the dialog list.
  Future<List<Contact>> fetchContacts();

  /// Stories from the user's contacts. Throws [UnimplementedError] when
  /// the backend has no stories support — the UI shows an empty state.
  Future<List<Story>> fetchStories();

  /// Live incoming messages pushed by the Telegram connection.
  Stream<ChatMessage> get incomingMessages;

  Future<void> logout();
  Future<void> dispose();
}

/// Signal: login must continue to the 2FA password screen.
/// Thrown by [TelegramApiService.signInWithCode] when the account has
/// two-step verification enabled. The UI catches this type specifically.
class NeedsTwoFactorAuth implements Exception {
  const NeedsTwoFactorAuth();
}

/// Build the real Telegram backend.
///
/// Throws [StateError] when this build has no API credentials compiled
/// in — i.e. the owner has not supplied api_id/api_hash yet. The UI
/// turns that into the "API not configured" state; it never falls back
/// to fake data.
TelegramApiService createTelegramService({required String sessionPath}) {
  if (!TelegramConfig.isConfigured) {
    throw StateError(
      'API keys not configured — owner must add api_id/api_hash. '
      'Keys go in the encrypted native store: '
      'android/app/src/main/cpp/telegram_keys.cpp and '
      'ios/Runner/telegram_keys.c. See README → "Going Live".',
    );
  }
  return live.LiveTelegramService(
    apiId: TelegramConfig.apiId,
    apiHash: TelegramConfig.apiHash,
    sessionPath: sessionPath,
  );
}
