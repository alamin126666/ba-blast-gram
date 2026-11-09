import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mtflute/mtflute.dart' hide Chat, Contact;

import '../models/models.dart';
import 'telegram_api_service.dart';

/// Real Telegram backend: the MTProto client.
///
/// Uses the pure-Dart `mtflute` package (Telegram API layer 228, no
/// native libraries, no platform channels). Only compiled on
/// mobile/desktop — see `live_telegram_service_stub.dart` for web.
///
/// Credentials come from [TelegramConfig] — the OWNER's api_id/api_hash
/// stored encrypted in the native library (see
/// lib/config/telegram_keys.dart). They are never typed in by end users
/// and never stored in plain text in this repo.
///
/// What is real here (all verified against mtflute 0.2.9):
/// * Login: [MtpClient.sendCode] → OTP → [MtpClient.signIn] →
///   [MtpClient.checkPassword] for 2FA (SRP). Sessions are file-based,
///   so a login survives app restarts; [MtpClient.isAuthorized] resumes.
/// * Chats: [MtpClient.getDialogs] mapped to [Chat] (personal / group /
///   channel / bot / Saved Messages, unread, pinned, verified, online).
/// * Messages: [MtpClient.getHistory] mapped to [ChatMessage]
///   (text, photo, voice, file, replies, forwards, reactions, edits).
/// * Sending: [MtpClient.sendMessage] with optional reply-to.
/// * Profile: [MtpClient.getMe]. Contacts: derived from dialog users.
/// * Live incoming messages via [MtpClient.onMessage] → [incomingMessages].
///
/// Honest limits (see README → "Known limits"):
/// * Stories sync is not wired — mtflute 0.2.9 exposes no stories
///   helper, so [fetchStories] reports that instead of fake stories.
/// * Voice/video calls need TDLib native libraries — not in this build.
/// * Group/channel creation on the server is not wired yet; the app
///   creates the conversation locally (see AppState).
class LiveTelegramService implements TelegramApiService {
  LiveTelegramService({
    required this.apiId,
    required this.apiHash,
    required this.sessionPath,
  });

  final int apiId;
  final String apiHash;

  /// Absolute path of the mtflute session file, e.g.
  /// `<app docs>/mtflute.session` (from path_provider).
  final String sessionPath;

  MtpClient? _client;
  String? _phoneNumber;
  String? _codeHash;
  int? _myUserId;
  bool _loggedIn = false;

  /// My chat id → the Telegram peer needed to load/send messages.
  final Map<String, InputPeer> _peers = <String, InputPeer>{};

  /// My chat id → display title (for channel posts, where the sender
  /// is the channel itself).
  final Map<String, String> _titles = <String, String>{};

  final StreamController<ChatMessage> _incomingController =
      StreamController<ChatMessage>.broadcast();

  @override
  Stream<ChatMessage> get incomingMessages => _incomingController.stream;

  /// Phone number the current login attempt is for, if any.
  String? get phoneNumber => _phoneNumber;

  @override
  bool get isLoggedIn => _loggedIn;

  MtpClient _ensureClient() {
    final existing = _client;
    if (existing != null) return existing;
    final client = MtpClient(
      appId: apiId,
      appHash: apiHash,
      sessionFile: sessionPath,
    );
    client.onMessage(_handleIncoming);
    _client = client;
    return client;
  }

  void _handleIncoming(NewMessage event) {
    final chatId = _chatIdForPeer(event.peer);
    _peers.putIfAbsent(chatId, () => event.peer);
    final msg = _mapMessage(
      event.message,
      usersById: <int, UserObj>{
        if (event.sender != null) event.sender!.id: event.sender!,
      },
      chatTitle: _titleForChat(chatId),
    );
    final routed = ChatMessage(
      id: msg.id,
      chatId: chatId,
      senderId: msg.senderId,
      senderName: msg.senderName,
      text: msg.text,
      time: msg.time,
      isMine: msg.isMine,
      kind: msg.kind,
      replyTo: msg.replyTo,
      forwardedFrom: msg.forwardedFrom,
      reactions: msg.reactions,
      read: msg.read,
      durationSeconds: msg.durationSeconds,
      mediaLabel: msg.mediaLabel,
      mediaCount: msg.mediaCount,
      edited: msg.edited,
    );
    if (!_incomingController.isClosed) _incomingController.add(routed);
  }

  /// Network calls to Telegram must never spin forever: mtflute retries
  /// internally for up to 2 minutes per call, so without an app-level
  /// timeout a dead network leaves the login button loading indefinitely
  /// with no error. 45s per call is enough for a slow first connection
  /// (auth-key exchange) and still fails fast with a clear message.
  static Future<T> _withTimeout<T>(Future<T> future) {
    return future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw StateError(
        'Connection timed out — check your internet and try again.',
      ),
    );
  }

  // ------------------------------------------------------------------ auth
  @override
  Future<void> sendCode(String phoneNumber) async {
    final client = _ensureClient();
    _phoneNumber = phoneNumber;
    if (await _withTimeout(client.isAuthorized())) {
      _loggedIn = true;
      await _loadMe(client);
      return;
    }
    final sent = await _withTimeout(client.sendCode(phoneNumber));
    if (sent is AuthSentCodeObj) {
      _codeHash = sent.phoneCodeHash;
    } else {
      throw StateError('Telegram did not return a code hash. Try again.');
    }
  }

  @override
  Future<void> signInWithCode(String code) async {
    final client = _ensureClient();
    final phone = _phoneNumber;
    final codeHash = _codeHash;
    if (phone == null || codeHash == null) {
      throw StateError('Ask for a code first (enter your phone number).');
    }
    try {
      await _withTimeout(
        client.signIn(phone: phone, codeHash: codeHash, code: code.trim()),
      );
    } on MtpRpcError catch (e) {
      if (e.matches('SESSION_PASSWORD_NEEDED')) {
        throw const NeedsTwoFactorAuth();
      }
      if (e.matches('PHONE_CODE_INVALID')) {
        throw StateError('Wrong code. Check the OTP Telegram sent you.');
      }
      if (e.matches('PHONE_CODE_EXPIRED')) {
        throw StateError('That code expired. Ask for a new one.');
      }
      throw StateError(_rpcMessage(e));
    }
    _loggedIn = true;
    await _loadMe(client);
  }

  @override
  Future<void> signInWithPassword(String password) async {
    final client = _ensureClient();
    try {
      // Do NOT call client.checkPassword() here: mtflute's SRP step
      // (PBKDF2-HMAC-SHA512 x100k + 2048-bit modPow, all pure Dart)
      // runs synchronously on the calling isolate and blocks the UI
      // thread for tens of seconds, which Android reports as
      // "BA BLAST GRAM isn't responding" (ANR). Instead, do the two
      // network calls here and run only the SRP maths in a background
      // isolate via compute(), keeping the UI responsive.
      final pwd =
          await _withTimeout(client.invoke(AccountGetPasswordRequest()))
              as AccountPasswordObj;
      final algo = pwd.currentAlgo;
      if (algo
          is! PasswordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow) {
        throw StateError(
          'Unsupported password algorithm: ${algo.runtimeType}',
        );
      }
      final srpB = pwd.srpB;
      final srpId = pwd.srpId;
      if (srpB == null || srpId == null) {
        throw StateError(
          'Could not start two-step verification. Try again.',
        );
      }
      final answer = await compute(_srpCheckIsolate, <String, dynamic>{
        'password': password,
        'srpB': srpB,
        'salt1': algo.salt1,
        'salt2': algo.salt2,
        'g': algo.g,
        'p': algo.p,
      });
      if (answer == null) {
        throw StateError('Enter your 2FA password.');
      }
      await _withTimeout(
        client.invoke(
          AuthCheckPasswordRequest(
            password: InputCheckPasswordSRPObj(
              srpId: srpId,
              A: answer.ga,
              M1: answer.m1,
            ),
          ),
        ),
      );
    } on MtpRpcError catch (e) {
      if (e.matches('PASSWORD_HASH_INVALID')) {
        throw StateError('Wrong 2FA password. Try again.');
      }
      throw StateError(_rpcMessage(e));
    }
    _loggedIn = true;
    await _loadMe(client);
  }

  Future<void> _loadMe(MtpClient client) async {
    try {
      final me = await client.getMe();
      if (me is UserObj) _myUserId = me.id;
    } catch (_) {
      // Profile loading is best-effort; login already succeeded.
    }
  }

  static String _rpcMessage(MtpRpcError e) {
    final detail = e.description ?? e.message;
    return detail.isEmpty ? 'Telegram error (${e.code}).' : detail;
  }

  // ------------------------------------------------------------------ data
  Future<void> _requireAuth() async {
    final client = _ensureClient();
    if (_loggedIn) return;
    if (await client.isAuthorized()) {
      _loggedIn = true;
      await _loadMe(client);
      return;
    }
    throw StateError('Telegram session expired — please log in again.');
  }

  @override
  Future<List<Chat>> fetchChats() async {
    await _requireAuth();
    final client = _ensureClient();
    final result = await client.getDialogs(limit: 100);
    final List<Dialog> dialogs;
    final List<Message> messages;
    // mtflute's Chat is hidden (it clashes with the app's Chat model),
    // so the dialog chats stay dynamic here and are narrowed with
    // whereType<ChatObj>() / whereType<Channel>() below.
    final List<dynamic> chats;
    final List<User> users;
    if (result is MessagesDialogsObj) {
      dialogs = result.dialogs;
      messages = result.messages;
      chats = result.chats;
      users = result.users;
    } else if (result is MessagesDialogsSlice) {
      dialogs = result.dialogs;
      messages = result.messages;
      chats = result.chats;
      users = result.users;
    } else {
      return <Chat>[];
    }

    final usersById = <int, UserObj>{
      for (final u in users.whereType<UserObj>()) u.id: u,
    };
    final chatsById = <int, ChatObj>{
      for (final c in chats.whereType<ChatObj>()) c.id: c,
    };
    final channelsById = <int, Channel>{
      for (final c in chats.whereType<Channel>()) c.id: c,
    };
    final messagesById = <int, MessageObj>{
      for (final m in messages.whereType<MessageObj>()) m.id: m,
    };

    final out = <Chat>[];
    for (final dialog in dialogs.whereType<DialogObj>()) {
      final peer = dialog.peer;
      final top = messagesById[dialog.topMessage];
      final lastText = top == null ? '' : _messagePreview(top);
      final lastTime = top == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(top.date * 1000);
      if (peer is PeerUser) {
        final user = usersById[peer.userId];
        final name = user == null ? 'User ${peer.userId}' : _displayName(user);
        final isSelf = peer.userId == _myUserId;
        final id = isSelf ? 'saved' : 'user_${peer.userId}';
        final inputPeer = InputPeerUser(
          userId: peer.userId,
          accessHash: user?.accessHash ?? 0,
        );
        _peers[id] = inputPeer;
        _titles[id] = isSelf ? 'Saved Messages' : name;
        out.add(
          Chat(
            id: id,
            title: isSelf ? 'Saved Messages' : name,
            type: isSelf
                ? ChatType.saved
                : (user?.bot ?? false ? ChatType.bot : ChatType.personal),
            username: user?.username,
            lastMessage: lastText,
            lastTime: lastTime,
            unread: dialog.unreadCount,
            pinned: dialog.pinned,
            verified: user?.verified ?? false,
            isOnline: user?.status is UserStatusOnline,
            colorValue: _colorFor(id),
          ),
        );
      } else if (peer is PeerChat) {
        final chat = chatsById[peer.chatId];
        final id = 'chat_${peer.chatId}';
        _peers[id] = InputPeerChat(chatId: peer.chatId);
        _titles[id] = chat?.title ?? 'Group ${peer.chatId}';
        out.add(
          Chat(
            id: id,
            title: chat?.title ?? 'Group ${peer.chatId}',
            type: ChatType.group,
            lastMessage: lastText,
            lastTime: lastTime,
            unread: dialog.unreadCount,
            pinned: dialog.pinned,
            members: chat?.participantsCount ?? 0,
            colorValue: _colorFor(id),
          ),
        );
      } else if (peer is PeerChannel) {
        final channel = channelsById[peer.channelId];
        final id = 'channel_${peer.channelId}';
        _peers[id] = InputPeerChannel(
          channelId: peer.channelId,
          accessHash: channel?.accessHash ?? 0,
        );
        _titles[id] = channel?.title ?? 'Channel ${peer.channelId}';
        out.add(
          Chat(
            id: id,
            title: channel?.title ?? 'Channel ${peer.channelId}',
            type: (channel?.megagroup ?? false)
                ? ChatType.group
                : ChatType.channel,
            username: channel?.username,
            lastMessage: lastText,
            lastTime: lastTime,
            unread: dialog.unreadCount,
            pinned: dialog.pinned,
            verified: channel?.verified ?? false,
            members: channel?.participantsCount ?? 0,
            colorValue: _colorFor(id),
          ),
        );
      }
    }
    return out;
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String chatId) async {
    await _requireAuth();
    final peer = _peers[chatId];
    if (peer == null) {
      throw StateError('Unknown chat — reload the chat list first.');
    }
    final client = _ensureClient();
    final result = await client.getHistory(peer: peer, limit: 100);
    final List<Message> messages;
    final List<User> users;
    if (result is MessagesMessagesObj) {
      messages = result.messages;
      users = result.users;
    } else if (result is MessagesMessagesSlice) {
      messages = result.messages;
      users = result.users;
    } else if (result is MessagesChannelMessages) {
      messages = result.messages;
      users = result.users;
    } else {
      return <ChatMessage>[];
    }
    final usersById = <int, UserObj>{
      for (final u in users.whereType<UserObj>()) u.id: u,
    };
    final textById = <int, String>{
      for (final m in messages.whereType<MessageObj>()) m.id: m.message,
    };
    final chatTitle = _titleForChat(chatId);
    final mapped = messages
        .whereType<MessageObj>()
        .map(
          (m) => _mapMessage(
            m,
            usersById: usersById,
            chatTitle: chatTitle,
            textById: textById,
          ),
        )
        .toList();
    // getHistory returns newest first; the UI shows oldest first.
    return mapped.reversed
        .map(
          (m) => ChatMessage(
            id: m.id,
            chatId: chatId,
            senderId: m.senderId,
            senderName: m.senderName,
            text: m.text,
            time: m.time,
            isMine: m.isMine,
            kind: m.kind,
            replyTo: m.replyTo,
            forwardedFrom: m.forwardedFrom,
            reactions: m.reactions,
            read: m.read,
            durationSeconds: m.durationSeconds,
            mediaLabel: m.mediaLabel,
            mediaCount: m.mediaCount,
            edited: m.edited,
          ),
        )
        .toList();
  }

  @override
  Future<ChatMessage> sendMessage(
    String chatId,
    String text, {
    String? replyToId,
  }) async {
    await _requireAuth();
    final peer = _peers[chatId];
    if (peer == null) {
      throw StateError('Unknown chat — reload the chat list first.');
    }
    final client = _ensureClient();
    final replyToMsgId = replyToId == null
        ? null
        : int.tryParse(replyToId.replaceFirst(RegExp(r'^m_'), ''));
    final result = await client.sendMessage(
      peer: peer,
      text: text,
      replyToMsgId: replyToMsgId,
    );
    // The send returns Updates — pull the real message out of it.
    if (result is UpdatesObj) {
      for (final update in result.updates) {
        if (update is UpdateNewMessage) {
          final created = update.message;
          if (created is MessageObj) {
            return _mapMessage(
              created,
              usersById: <int, UserObj>{},
              chatTitle: _titleForChat(chatId),
            ).withChat(chatId);
          }
        }
      }
    }
    // Fallback: the send succeeded but the update shape was unexpected.
    return ChatMessage(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: 'me',
      senderName: 'You',
      text: text,
      time: DateTime.now(),
      isMine: true,
      replyTo: replyToId,
    );
  }

  @override
  Future<void> forwardMessage({
    required String fromChatId,
    required String toChatId,
    required String messageId,
  }) async {
    await _requireAuth();
    final fromPeer = _peers[fromChatId];
    final toPeer = _peers[toChatId];
    if (fromPeer == null || toPeer == null) {
      throw StateError('Unknown chat — reload the chat list first.');
    }
    final id = int.tryParse(messageId.replaceFirst(RegExp(r'^m_'), ''));
    if (id == null) {
      throw StateError('Cannot forward this message (no Telegram id).');
    }
    await _ensureClient().forwardMessages(
      fromPeer: fromPeer,
      toPeer: toPeer,
      ids: <int>[id],
    );
  }

  @override
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    await _requireAuth();
    final peer = _peers[chatId];
    if (peer == null) {
      throw StateError('Unknown chat — reload the chat list first.');
    }
    final id = int.tryParse(messageId.replaceFirst(RegExp(r'^m_'), ''));
    if (id == null) {
      throw StateError('Cannot delete this message (no Telegram id).');
    }
    await _ensureClient().deleteMessages(peer: peer, ids: <int>[id]);
  }

  @override
  Future<UserProfile?> fetchMe() async {
    await _requireAuth();
    final client = _ensureClient();
    final me = await client.getMe();
    if (me is! UserObj) return null;
    _myUserId = me.id;
    return UserProfile(
      id: 'user_${me.id}',
      name: _displayName(me),
      username: me.username,
      phone: me.phone,
      bio: '',
      colorValue: _colorFor('user_${me.id}'),
      isOnline: true,
      lastSeen: 'online',
    );
  }

  @override
  Future<List<Contact>> fetchContacts() async {
    await _requireAuth();
    final client = _ensureClient();
    // No dedicated contacts helper in mtflute 0.2.9 — contacts are the
    // real users from the dialog list (people you actually chat with).
    final result = await client.getDialogs(limit: 100);
    final List<User> users;
    if (result is MessagesDialogsObj) {
      users = result.users;
    } else if (result is MessagesDialogsSlice) {
      users = result.users;
    } else {
      return <Contact>[];
    }
    final seen = <int>{};
    final out = <Contact>[];
    for (final user in users.whereType<UserObj>()) {
      if (user.id == _myUserId || !seen.add(user.id)) continue;
      out.add(
        Contact(
          id: 'user_${user.id}',
          name: _displayName(user),
          username: user.username,
          phone: user.phone,
          isOnline: user.status is UserStatusOnline,
          lastSeen: _lastSeenLabel(user),
          colorValue: _colorFor('user_${user.id}'),
        ),
      );
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  @override
  Future<List<Story>> fetchStories() async {
    // mtflute 0.2.9 exposes no stories helper, so there is nothing real
    // to return. The UI shows an honest empty state instead of fake data.
    throw UnimplementedError(
      'Live stories sync is not wired yet — mtflute 0.2.9 exposes no '
      'stories helper. See README → "Known limits".',
    );
  }

  /// Export the mtflute string session (gogram-compatible `1BvE` format)
  /// so the owner can back it up or move it to another device.
  String? exportSession() => _client?.exportSession();

  @override
  Future<void> logout() async {
    _loggedIn = false;
    _phoneNumber = null;
    _codeHash = null;
    _peers.clear();
    _titles.clear();
    try {
      await _client?.logOut();
    } catch (_) {
      // Server logout is best-effort; local close still runs.
    }
    await _client?.close();
    _client = null;
  }

  @override
  Future<void> dispose() async {
    await _incomingController.close();
    await _client?.close();
  }

  // ---------------------------------------------------------------- mapping
  static String _displayName(UserObj user) {
    final first = (user.firstName ?? '').trim();
    final last = (user.lastName ?? '').trim();
    final full = <String>[first, last].where((s) => s.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    if ((user.username ?? '').isNotEmpty) return '@${user.username}';
    if ((user.phone ?? '').isNotEmpty) return user.phone!;
    return 'User ${user.id}';
  }

  static String _lastSeenLabel(UserObj user) {
    final status = user.status;
    if (status is UserStatusOnline) return 'online';
    if (status is UserStatusRecently) return 'last seen recently';
    if (status is UserStatusLastWeek) return 'last seen within a week';
    if (status is UserStatusLastMonth) return 'last seen within a month';
    return 'last seen a long time ago';
  }

  static String _chatIdForPeer(InputPeer peer) {
    if (peer is InputPeerUser) return 'user_${peer.userId}';
    if (peer is InputPeerChannel) return 'channel_${peer.channelId}';
    if (peer is InputPeerChat) return 'chat_${peer.chatId}';
    return 'peer_${peer.hashCode}';
  }

  String _titleForChat(String chatId) {
    return _titles[chatId] ?? chatId;
  }

  static int _colorFor(String seed) {
    const palette = <int>[
      0xFF1C93D1,
      0xFF6C5CE7,
      0xFF00A884,
      0xFFE76F51,
      0xFFD6336C,
      0xFF2F9E44,
      0xFFF08C00,
      0xFF1971C2,
    ];
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = (hash * 31 + seed.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return palette[hash % palette.length];
  }

  static String _messagePreview(MessageObj msg) {
    if (msg.message.isNotEmpty) return msg.message;
    final media = msg.media;
    if (media is MessageMediaPhoto) return '📷 Photo';
    if (media is MessageMediaDocument) {
      if (media.voice) return '🎙️ Voice message';
      if (media.video) return '📹 Video';
      return '📎 File';
    }
    if (media is MessageMediaGeo) return '📍 Location';
    if (media is MessageMediaContact) return '👤 Contact';
    if (media is MessageMediaPoll) return '📊 Poll';
    return 'Message';
  }

  ChatMessage _mapMessage(
    MessageObj msg, {
    required Map<int, UserObj> usersById,
    required String chatTitle,
    Map<int, String>? textById,
  }) {
    final fromId = msg.fromId;
    final senderUser = fromId is PeerUser ? usersById[fromId.userId] : null;
    final isMine = msg.out || (senderUser?.id == _myUserId);
    final senderName = isMine
        ? 'You'
        : senderUser != null
            ? _displayName(senderUser)
            : (msg.postAuthor ?? chatTitle);
    final senderId = senderUser != null
        ? 'user_${senderUser.id}'
        : (fromId is PeerUser
            ? 'user_${fromId.userId}'
            : (fromId is PeerChannel
                ? 'channel_${fromId.channelId}'
                : 'me'));

    var kind = MessageKind.text;
    int? durationSeconds;
    String? mediaLabel;
    final media = msg.media;
    if (media is MessageMediaPhoto) {
      kind = MessageKind.photo;
      mediaLabel = 'Photo';
    } else if (media is MessageMediaDocument) {
      if (media.voice) {
        kind = MessageKind.voice;
        mediaLabel = 'Voice message';
        final doc = media.document;
        if (doc is DocumentObj) {
          for (final attr in doc.attributes) {
            if (attr is DocumentAttributeAudio) {
              durationSeconds = attr.duration;
            }
          }
        }
      } else if (media.video) {
        kind = MessageKind.video;
        mediaLabel = 'Video';
      } else {
        kind = MessageKind.file;
        mediaLabel = 'File';
      }
    } else if (media is MessageMediaGeo) {
      kind = MessageKind.location;
      mediaLabel = 'Location';
    }

    String? replyTo;
    final reply = msg.replyTo;
    if (reply is MessageReplyHeaderObj && reply.replyToMsgId != null) {
      final original = textById?[reply.replyToMsgId];
      replyTo = original != null && original.isNotEmpty
          ? original
          : 'Reply to message #${reply.replyToMsgId}';
    }

    String? forwardedFrom;
    final fwd = msg.fwdFrom;
    if (fwd is MessageFwdHeaderObj) {
      if ((fwd.fromName ?? '').isNotEmpty) {
        forwardedFrom = fwd.fromName;
      } else if (fwd.fromId is PeerUser) {
        final fromUser = usersById[(fwd.fromId as PeerUser).userId];
        forwardedFrom =
            fromUser != null ? _displayName(fromUser) : 'Forwarded message';
      } else {
        forwardedFrom = 'Forwarded message';
      }
    }

    final reactions = <String>[];
    final rx = msg.reactions;
    if (rx is MessageReactionsObj) {
      for (final result in rx.results) {
        if (result is ReactionCountObj) {
          final reaction = result.reaction;
          if (reaction is ReactionEmoji) {
            reactions.add(reaction.emoticon);
          }
        }
      }
    }

    return ChatMessage(
      id: 'm_${msg.id}',
      chatId: '',
      senderId: senderId,
      senderName: senderName,
      text: msg.message.isNotEmpty ? msg.message : _messagePreview(msg),
      time: DateTime.fromMillisecondsSinceEpoch(msg.date * 1000),
      isMine: isMine,
      kind: kind,
      replyTo: replyTo,
      forwardedFrom: forwardedFrom,
      reactions: reactions,
      read: true,
      durationSeconds: durationSeconds,
      mediaLabel: mediaLabel,
      edited: msg.editDate != null,
    );
  }
}

extension _ChatMessageChat on ChatMessage {
  ChatMessage withChat(String chatId) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      time: time,
      isMine: isMine,
      kind: kind,
      replyTo: replyTo,
      forwardedFrom: forwardedFrom,
      reactions: reactions,
      read: read,
      durationSeconds: durationSeconds,
      mediaLabel: mediaLabel,
      mediaCount: mediaCount,
      edited: edited,
    );
  }
}

/// Runs mtflute's SRP maths in a background isolate. Must be a top-level
/// function for [compute]. Takes only plain transferable values (String,
/// Uint8List, int) and returns the SRP answer (two Uint8Lists).
SrpAnswer? _srpCheckIsolate(Map<String, dynamic> args) {
  return computeSrpCheck(
    password: args['password'] as String,
    srpB: args['srpB'] as Uint8List,
    salt1: args['salt1'] as Uint8List,
    salt2: args['salt2'] as Uint8List,
    g: args['g'] as int,
    p: args['p'] as Uint8List,
  );
}
