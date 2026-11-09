// Data models for BA BLAST GRAM.
//
// These are plain, UI-independent value objects. The TelegramApiService
// produces them, and AppState holds them for the UI.

/// Initials for an avatar: first letters of the first two words,
/// or the first two letters of a single word.
String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    return word.length >= 2
        ? word.substring(0, 2).toUpperCase()
        : word.toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

enum ChatType { personal, group, channel, saved, bot }

enum MessageKind { text, photo, video, voice, file, sticker, location }

enum CallKind { voice, video }

enum CallDirection { incoming, outgoing, missed }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    this.username,
    this.phone,
    this.bio = '',
    this.colorValue = 0xFF1C93D1,
    this.isOnline = false,
    this.lastSeen = '',
  });

  final String id;
  final String name;
  final String? username;
  final String? phone;
  final String bio;
  final int colorValue;
  final bool isOnline;
  final String lastSeen;

String get initials => initialsFor(name);
}

class Chat {
  Chat({
    required this.id,
    required this.title,
    required this.type,
    this.username,
    this.lastMessage = '',
    DateTime? lastTime,
    this.unread = 0,
    this.pinned = false,
    this.muted = false,
    this.verified = false,
    this.isOnline = false,
    this.typing = false,
    this.colorValue = 0xFF1C93D1,
    this.members = 0,
    this.isDraft = false,
  }) : lastTime = lastTime ?? _epoch;

  static final DateTime _epoch = DateTime(2026, 11, 9, 9, 0);

  final String id;
  final String title;
  final ChatType type;
  final String? username;
  final String lastMessage;
  final DateTime lastTime;
  final int unread;
  final bool pinned;
  final bool muted;
  final bool verified;
  final bool isOnline;
  final bool typing;
  final int colorValue;
  final int members;
  final bool isDraft;

String get initials => initialsFor(title);

  bool get isChannel => type == ChatType.channel;
  bool get isGroup => type == ChatType.group;

  Chat copyWith({
    String? lastMessage,
    DateTime? lastTime,
    int? unread,
    bool? pinned,
    bool? muted,
    bool? typing,
    bool? isOnline,
  }) {
    return Chat(
      id: id,
      title: title,
      type: type,
      username: username,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTime: lastTime ?? this.lastTime,
      unread: unread ?? this.unread,
      pinned: pinned ?? this.pinned,
      muted: muted ?? this.muted,
      verified: verified,
      isOnline: isOnline ?? this.isOnline,
      typing: typing ?? this.typing,
      colorValue: colorValue,
      members: members,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.time,
    this.isMine = false,
    this.kind = MessageKind.text,
    this.replyTo,
    this.forwardedFrom,
    this.reactions = const [],
    this.read = true,
    this.durationSeconds,
    this.mediaLabel,
    this.mediaCount = 0,
    this.edited = false,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime time;
  final bool isMine;
  final MessageKind kind;
  final String? replyTo;
  final String? forwardedFrom;
  final List<String> reactions;
  final bool read;
  final int? durationSeconds;
  final String? mediaLabel;
  final int mediaCount;
  final bool edited;

  ChatMessage copyWith({List<String>? reactions, bool? read, String? text}) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      text: text ?? this.text,
      time: time,
      isMine: isMine,
      kind: kind,
      replyTo: replyTo,
      forwardedFrom: forwardedFrom,
      reactions: reactions ?? this.reactions,
      read: read ?? this.read,
      durationSeconds: durationSeconds,
      mediaLabel: mediaLabel,
      mediaCount: mediaCount,
      edited: edited,
    );
  }
}

class Contact {
  const Contact({
    required this.id,
    required this.name,
    this.username,
    this.phone,
    this.isOnline = false,
    this.lastSeen = '',
    this.colorValue = 0xFF1C93D1,
  });

  final String id;
  final String name;
  final String? username;
  final String? phone;
  final bool isOnline;
  final String lastSeen;
  final int colorValue;

String get initials => initialsFor(name);
}

class Story {
  Story({
    required this.id,
    required this.userId,
    required this.userName,
    this.viewed = false,
    this.isMine = false,
    this.colorValue = 0xFF1C93D1,
    DateTime? time,
  }) : time = time ?? _epoch;

  static final DateTime _epoch = DateTime(2026, 11, 9, 8, 30);

  final String id;
  final String userId;
  final String userName;
  final bool viewed;
  final bool isMine;
  final int colorValue;
  final DateTime time;

String get initials => initialsFor(userName);
}

class CallRecord {
  const CallRecord({
    required this.id,
    required this.contactName,
    required this.kind,
    required this.direction,
    required this.time,
    this.duration,
    this.colorValue = 0xFF1C93D1,
  });

  final String id;
  final String contactName;
  final CallKind kind;
  final CallDirection direction;
  final DateTime time;
  final Duration? duration;
  final int colorValue;

String get initials => initialsFor(contactName);
}
