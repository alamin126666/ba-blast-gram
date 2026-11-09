import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/telegram_config.dart';
import '../models/models.dart';
import '../services/telegram_api_service.dart';

/// Chat-list folders, like Telegram's chat folders.
enum ChatFolder { all, personal, groups, channels, unread }

/// Login progress, mirrored by the login screens.
enum AuthStep { loggedOut, awaitingCode, awaitingPassword, loggedIn }

/// Central state for BA BLAST GRAM, exposed with Provider.
///
/// Real Telegram only. This owns the live
/// [TelegramApiService] (MTProto via mtflute, using the owner's api_id /
/// api_hash stored encrypted in the native library), the signed-in user, chats/messages,
/// contacts, stories and settings. Screens only read this — they never
/// talk to a service directly.
///
/// Until the owner's keys are loaded from the native store,
/// [apiConfigured] is false, no service exists, and the UI shows the
/// "API not configured" state on the login screen.
class AppState extends ChangeNotifier {
  AppState();

  // ---------------------------------------------------------------- prefs
  static const String _kDarkTheme = 'bbg_dark_theme';
  static const String _kLoggedIn = 'bbg_logged_in';
  static const String _kPhone = 'bbg_phone';
  static const String _kUserName = 'bbg_user_name';
  static const String _kUserBio = 'bbg_user_bio';

  SharedPreferences? _prefs;
  bool _initialized = false;
  bool get initialized => _initialized;

  // ------------------------------------------------------------- credentials
  /// True only when the owner's api_id/api_hash were loaded from
  /// the encrypted native key store. End users never supply keys.
  bool get apiConfigured => TelegramConfig.isConfigured;

  // ---------------------------------------------------------------- backend
  TelegramApiService? _service;
  StreamSubscription<ChatMessage>? _incomingSub;

  // ------------------------------------------------------------------ auth
  AuthStep _authStep = AuthStep.loggedOut;
  AuthStep get authStep => _authStep;
  bool get isLoggedIn => _authStep == AuthStep.loggedIn;

  String _phoneNumber = '';
  String get phoneNumber => _phoneNumber;

  UserProfile _me = const UserProfile(
    id: 'me',
    name: 'BA User',
    bio: '',
    colorValue: 0xFF1C93D1,
  );
  UserProfile get me => _me;

  String? _authError;
  String? get authError => _authError;

  bool _authBusy = false;
  bool get authBusy => _authBusy;

  // ------------------------------------------------------------------ data
  List<Chat> _chats = <Chat>[];
  List<Chat> get chats => List<Chat>.unmodifiable(_chats);

  final Map<String, List<ChatMessage>> _messages =
      <String, List<ChatMessage>>{};
  List<Contact> _contacts = <Contact>[];
  List<Contact> get contacts => List<Contact>.unmodifiable(_contacts);
  List<Story> _stories = <Story>[];
  List<Story> get stories => List<Story>.unmodifiable(_stories);

  /// Call attempts made from this device (local log). Voice/video
  /// calling over the Telegram network needs the TDLib native library
  /// and is not in this build — see README → "Known limits".
  List<CallRecord> _calls = <CallRecord>[];
  List<CallRecord> get calls => List<CallRecord>.unmodifiable(_calls);

  void logCall(CallRecord call) {
    _calls.insert(0, call);
    notifyListeners();
  }

  bool _loadingChats = false;
  bool get loadingChats => _loadingChats;

  ChatFolder _folder = ChatFolder.all;
  ChatFolder get folder => _folder;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // -------------------------------------------------------------- settings
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  // ------------------------------------------------------------------ init
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = (_prefs!.getBool(_kDarkTheme) ?? false)
        ? ThemeMode.dark
        : ThemeMode.light;
    _phoneNumber = _prefs!.getString(_kPhone) ?? '';
    final savedName = _prefs!.getString(_kUserName);
    final savedBio = _prefs!.getString(_kUserBio);
    if (savedName != null && savedName.isNotEmpty) {
      _me = UserProfile(
        id: _me.id,
        name: savedName,
        phone: _phoneNumber.isEmpty ? null : _phoneNumber,
        bio: savedBio ?? '',
        colorValue: _me.colorValue,
        isOnline: true,
        lastSeen: 'online',
      );
    }
    if (apiConfigured) {
      _buildService();
      if (_prefs!.getBool(_kLoggedIn) ?? false) {
        // A previous mtflute session may still be valid — try to resume.
        _authStep = AuthStep.loggedIn;
        await loadChats();
        await refreshMe();
        _subscribeIncoming();
        if (_chats.isEmpty && _authError != null) {
          // Session did not resume; fall back to the login screen.
          _authStep = AuthStep.loggedOut;
        }
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<String> _sessionPath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/mtflute.session';
    } catch (_) {
      // Web (or any platform without a documents dir): the live stub
      // ignores the path.
      return 'mtflute.session';
    }
  }

  Future<void> _buildService() async {
    final path = await _sessionPath();
    _service = createTelegramService(sessionPath: path);
  }

  // ------------------------------------------------------------------ auth
  Future<void> sendCode(String phone) async {
    _authBusy = true;
    _authError = null;
    _phoneNumber = phone.trim();
    notifyListeners();
    try {
      _service ??= createTelegramService(
        sessionPath: await _sessionPath(),
      );
      await _service!.sendCode(_phoneNumber);
      _authStep = AuthStep.awaitingCode;
      await _prefs?.setString(_kPhone, _phoneNumber);
    } catch (e) {
      _authError = _friendlyError(e);
    } finally {
      _authBusy = false;
      notifyListeners();
    }
  }

  Future<void> submitCode(String code) async {
    _authBusy = true;
    _authError = null;
    notifyListeners();
    try {
      await _service!.signInWithCode(code.trim());
      await _completeLogin();
    } on NeedsTwoFactorAuth {
      _authStep = AuthStep.awaitingPassword;
    } catch (e) {
      _authError = _friendlyError(e);
    } finally {
      _authBusy = false;
      notifyListeners();
    }
  }

  Future<void> submitPassword(String password) async {
    _authBusy = true;
    _authError = null;
    notifyListeners();
    try {
      await _service!.signInWithPassword(password);
      await _completeLogin();
    } catch (e) {
      _authError = _friendlyError(e);
    } finally {
      _authBusy = false;
      notifyListeners();
    }
  }

  Future<void> _completeLogin() async {
    _authStep = AuthStep.loggedIn;
    await _prefs?.setBool(_kLoggedIn, true);
    // Navigate to home NOW. The chat/profile loads run in the background
    // (home shows its own loading state) so a slow first sync can never
    // leave the user staring at the 2FA spinner with no error.
    notifyListeners();
    unawaited(refreshMe());
    unawaited(loadChats());
    unawaited(loadContacts());
    unawaited(loadStories());
    _subscribeIncoming();
  }

  /// Route live incoming messages into the open chat / chat list.
  void _subscribeIncoming() {
    _incomingSub?.cancel();
    final service = _service;
    if (service == null) return;
    _incomingSub = service.incomingMessages.listen((message) {
      final list = _messages[message.chatId];
      if (list != null) {
        list.add(message);
      }
      final index = _chats.indexWhere((c) => c.id == message.chatId);
      if (index != -1) {
        _updateChatPreview(_chats[index], message.text);
      } else {
        // A brand-new conversation — refresh the list to pick it up.
        loadChats();
      }
      notifyListeners();
    });
  }

  Future<void> logout({bool silent = false}) async {
    await _incomingSub?.cancel();
    _incomingSub = null;
    try {
      await _service?.logout();
    } catch (_) {
      // Logging out must never trap the user on a screen.
    }
    _authStep = AuthStep.loggedOut;
    _authError = null;
    _chats = <Chat>[];
    _messages.clear();
    _contacts = <Contact>[];
    _stories = <Story>[];
    _calls = <CallRecord>[];
    await _prefs?.setBool(_kLoggedIn, false);
    if (!silent) notifyListeners();
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    for (final prefix in <String>[
      'UnimplementedError: ',
      'UnsupportedError: ',
      'StateError: ',
    ]) {
      if (text.startsWith(prefix)) return text.substring(prefix.length);
    }
    return text;
  }

  // ------------------------------------------------------------------ chats
  Future<void> loadChats() async {
    if (_service == null) return;
    _loadingChats = true;
    notifyListeners();
    try {
      _chats = await _service!.fetchChats();
      _sortChats();
      _authError = null;
    } catch (e) {
      _authError = _friendlyError(e);
    } finally {
      _loadingChats = false;
      notifyListeners();
    }
  }

  Future<void> loadContacts() async {
    if (_service == null) return;
    try {
      _contacts = await _service!.fetchContacts();
      notifyListeners();
    } catch (_) {
      // Contacts sync is best-effort in this build; chats still work.
      _contacts = <Contact>[];
    }
  }

  Future<void> loadStories() async {
    if (_service == null) return;
    try {
      _stories = await _service!.fetchStories();
      notifyListeners();
    } catch (_) {
      // Stories sync is best-effort in this build; chats still work.
      _stories = <Story>[];
    }
  }

  Future<void> refreshMe() async {
    if (_service == null) return;
    try {
      final me = await _service!.fetchMe();
      if (me != null) {
        _me = me;
        await _prefs?.setString(_kUserName, me.name);
        await _prefs?.setString(_kUserBio, me.bio);
        notifyListeners();
      }
    } catch (_) {
      // Keep the local placeholder profile; messaging still works.
    }
  }

  void _sortChats() {
    _chats.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.lastTime.compareTo(a.lastTime);
    });
  }

  List<Chat> get visibleChats {
    var list = _chats;
    switch (_folder) {
      case ChatFolder.personal:
        list = list
            .where(
              (c) => c.type == ChatType.personal || c.type == ChatType.saved,
            )
            .toList();
      case ChatFolder.groups:
        list = list.where((c) => c.type == ChatType.group).toList();
      case ChatFolder.channels:
        list = list.where((c) => c.type == ChatType.channel).toList();
      case ChatFolder.unread:
        list = list.where((c) => c.unread > 0).toList();
      case ChatFolder.all:
        break;
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (c) =>
                c.title.toLowerCase().contains(q) ||
                c.lastMessage.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  void setFolder(ChatFolder folder) {
    _folder = folder;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<List<ChatMessage>> messagesFor(Chat chat) async {
    final cached = _messages[chat.id];
    if (cached != null) return List<ChatMessage>.unmodifiable(cached);
    final loaded = await _service!.fetchMessages(chat.id);
    _messages[chat.id] = loaded;
    return List<ChatMessage>.unmodifiable(loaded);
  }

  List<ChatMessage> cachedMessages(String chatId) {
    return List<ChatMessage>.unmodifiable(_messages[chatId] ?? <ChatMessage>[]);
  }

  Future<void> sendMessage(
    Chat chat,
    String text, {
    String? replyToId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final sent = await _service!.sendMessage(
      chat.id,
      trimmed,
      replyToId: replyToId,
    );
    final list = _messages.putIfAbsent(chat.id, () => <ChatMessage>[]);
    list.add(sent);
    _updateChatPreview(chat, trimmed);
    notifyListeners();
  }

  void _updateChatPreview(Chat chat, String text) {
    final index = _chats.indexWhere((c) => c.id == chat.id);
    if (index == -1) return;
    _chats[index] = _chats[index].copyWith(
      lastMessage: text,
      lastTime: DateTime.now(),
    );
    _sortChats();
  }

  void markChatRead(Chat chat) {
    final index = _chats.indexWhere((c) => c.id == chat.id);
    if (index == -1 || _chats[index].unread == 0) return;
    _chats[index] = _chats[index].copyWith(unread: 0);
    notifyListeners();
  }

  void togglePin(Chat chat) {
    final index = _chats.indexWhere((c) => c.id == chat.id);
    if (index == -1) return;
    _chats[index] = _chats[index].copyWith(pinned: !_chats[index].pinned);
    _sortChats();
    notifyListeners();
  }

  void toggleMute(Chat chat) {
    final index = _chats.indexWhere((c) => c.id == chat.id);
    if (index == -1) return;
    _chats[index] = _chats[index].copyWith(muted: !_chats[index].muted);
    notifyListeners();
  }

  void deleteChat(Chat chat) {
    _chats.removeWhere((c) => c.id == chat.id);
    _messages.remove(chat.id);
    notifyListeners();
  }

  Future<void> forwardMessage(
    Chat fromChat,
    ChatMessage message,
    Chat toChat,
  ) async {
    await _service!.forwardMessage(
      fromChatId: fromChat.id,
      toChatId: toChat.id,
      messageId: message.id,
    );
    // The target chat's cached history is stale now — drop it so the
    // next open reloads the forwarded message from Telegram.
    _messages.remove(toChat.id);
    _updateChatPreview(toChat, message.text);
    notifyListeners();
  }

  Future<void> deleteMessage(Chat chat, ChatMessage message) async {
    await _service!.deleteMessage(chatId: chat.id, messageId: message.id);
    _messages[chat.id]?.removeWhere((m) => m.id == message.id);
    notifyListeners();
  }

  void toggleReaction(Chat chat, ChatMessage message, String emoji) {
    final list = _messages[chat.id];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == message.id);
    if (index == -1) return;
    final reactions = List<String>.from(list[index].reactions);
    if (reactions.contains(emoji)) {
      reactions.remove(emoji);
    } else {
      reactions.add(emoji);
    }
    list[index] = list[index].copyWith(reactions: reactions);
    notifyListeners();
  }

  /// Create a group locally and open it.
  ///
  /// NOTE: the server-side group creation call is a next wiring step for
  /// the MTProto layer (see README → "Known limits"). The conversation
  /// appears immediately so the flow can be used and tested.
  Chat createGroup(String name, List<Contact> members) {
    final chat = Chat(
      id: 'g-${DateTime.now().millisecondsSinceEpoch}',
      title: name,
      type: ChatType.group,
      lastMessage: 'Group created',
      lastTime: DateTime.now(),
      members: members.length + 1,
      colorValue: BlastColorsForGroup.pick(name),
    );
    _chats.insert(0, chat);
    _messages[chat.id] = <ChatMessage>[
      ChatMessage(
        id: 'm-welcome',
        chatId: chat.id,
        senderId: 'me',
        senderName: 'You',
        text: 'Group "$name" created with ${members.length} member(s).',
        time: DateTime.now(),
        isMine: true,
      ),
    ];
    _sortChats();
    notifyListeners();
    return chat;
  }

  /// Create a channel locally and open it. Same note as [createGroup].
  Chat createChannel(String name, String description) {
    final chat = Chat(
      id: 'ch-${DateTime.now().millisecondsSinceEpoch}',
      title: name,
      type: ChatType.channel,
      lastMessage: description.isEmpty ? 'Channel created' : description,
      lastTime: DateTime.now(),
      members: 1,
      colorValue: BlastColorsForGroup.pick(name),
    );
    _chats.insert(0, chat);
    _sortChats();
    notifyListeners();
    return chat;
  }

  // --------------------------------------------------------------- stories
  void markStoryViewed(Story story) {
    final index = _stories.indexWhere((s) => s.id == story.id);
    if (index == -1) return;
    _stories[index] = Story(
      id: story.id,
      userId: story.userId,
      userName: story.userName,
      viewed: true,
      isMine: story.isMine,
      colorValue: story.colorValue,
      time: story.time,
    );
    notifyListeners();
  }

  // -------------------------------------------------------------- settings
  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _prefs?.setBool(_kDarkTheme, _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setBool(_kDarkTheme, mode == ThemeMode.dark);
    notifyListeners();
  }

  void toggleNotifications(bool value) {
    _notificationsEnabled = value;
    notifyListeners();
  }

  /// Update the local display name / bio.
  /// NOTE: this changes the profile shown in the app only in this build;
  /// pushing it to Telegram's servers is a next wiring step.
  Future<void> updateProfile({
    required String name,
    required String bio,
  }) async {
    _me = UserProfile(
      id: _me.id,
      name: name.trim().isEmpty ? _me.name : name.trim(),
      username: _me.username,
      phone: _me.phone,
      bio: bio.trim(),
      colorValue: _me.colorValue,
      isOnline: true,
      lastSeen: 'online',
    );
    await _prefs?.setString(_kUserName, _me.name);
    await _prefs?.setString(_kUserBio, _me.bio);
    notifyListeners();
  }
}

/// Deterministic avatar colour helper kept out of the model layer.
class BlastColorsForGroup {
  const BlastColorsForGroup._();

  static int pick(String seed) {
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
}
