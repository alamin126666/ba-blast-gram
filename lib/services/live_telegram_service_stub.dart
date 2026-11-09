import '../models/models.dart';
import 'telegram_api_service.dart';

/// Web / non-`dart:io` build of the real Telegram backend.
///
/// mtflute is a pure-Dart MTProto client built on `dart:io`, so it has
/// no web target. This stub is selected by the conditional import in
/// `telegram_api_service.dart` whenever `dart:io` is unavailable, which
/// keeps `flutter build web` working. Real Telegram login on web is not
/// supported — use Android, iOS, macOS, Windows or Linux.
class LiveTelegramService implements TelegramApiService {
  LiveTelegramService({
    required int apiId,
    required String apiHash,
    required String sessionPath,
  });

  static const String _message =
      'Real Telegram login needs Android, iOS, macOS, Windows or Linux. '
      'On web, the MTProto client (mtflute) is dart:io based and cannot run.';

  @override
  bool get isLoggedIn => false;

  @override
  Future<void> sendCode(String phoneNumber) async {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> signInWithCode(String code) async {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> signInWithPassword(String password) async {
    throw UnsupportedError(_message);
  }

  @override
  Future<List<Chat>> fetchChats() async {
    throw UnsupportedError(_message);
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String chatId) async {
    throw UnsupportedError(_message);
  }

  @override
  Future<ChatMessage> sendMessage(
    String chatId,
    String text, {
    String? replyToId,
  }) async {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> forwardMessage({
    required String fromChatId,
    required String toChatId,
    required String messageId,
  }) async {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    throw UnsupportedError(_message);
  }

  @override
  Future<UserProfile?> fetchMe() async {
    throw UnsupportedError(_message);
  }

  @override
  Future<List<Contact>> fetchContacts() async {
    throw UnsupportedError(_message);
  }

  @override
  Future<List<Story>> fetchStories() async {
    throw UnsupportedError(_message);
  }

  @override
  Stream<ChatMessage> get incomingMessages =>
      const Stream<ChatMessage>.empty();

  @override
  Future<void> logout() async {}

  @override
  Future<void> dispose() async {}
}
