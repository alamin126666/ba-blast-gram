import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/avatars.dart';
import '../widgets/message_bubble.dart';
import 'calls.dart';
import 'settings_screens.dart';

/// One conversation: message history, composer with attach / emoji /
/// voice UI, reply, forward, delete and reactions.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chat});

  final Chat chat;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _loading = true;
  bool _sending = false;
  bool _showEmoji = false;
  bool _recording = false;
  String? _error;
  String? _replyToId;
  String _replyPreview = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await context.read<AppState>().messagesFor(widget.chat);
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('StateError: ', '');
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final chat = widget.chat;
    final messages = state.cachedMessages(chat.id);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChatInfoScreen(chat: chat),
            ),
          ),
          child: Row(
            children: <Widget>[
              BlastAvatar(
                name: chat.title,
                colorValue: chat.colorValue,
                size: 40,
                isOnline: chat.isOnline,
                isChannel: chat.isChannel,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            chat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                        if (chat.verified)
                          const Padding(
                            padding: EdgeInsets.only(left: 3),
                            child: Icon(
                              Icons.verified,
                              size: 15,
                              color: BlastColors.primary,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      chat.isGroup
                          ? '${chat.members} members'
                          : chat.isChannel
                              ? 'channel'
                              : chat.isOnline
                                  ? 'online'
                                  : 'last seen recently',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: chat.isOnline
                            ? BlastColors.primary
                            : Theme.of(context).colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () => _startCall(chat, CallKind.voice),
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () => _startCall(chat, CallKind.video),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? null
              : const Color(0xFFE7EBF0),
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.cloud_off,
                                  size: 44,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      _loading = true;
                                      _error = null;
                                    });
                                    _load();
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : messages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet.\nSay hello! 👋',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                final showDate = index == 0 ||
                                    !_sameDay(
                                      messages[index - 1].time,
                                      message.time,
                                    );
                                return Column(
                                  children: <Widget>[
                                    if (showDate)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: _DateChip(date: message.time),
                                      ),
                                    MessageBubble(
                                      message: message,
                                      isGroup: chat.isGroup,
                                      onLongPress: () =>
                                          _showMessageActions(message),
                                      onReplyTap: () {},
                                    ),
                                  ],
                                );
                              },
                            ),
            ),
            if (_replyToId != null) _replyBar(),
            if (_recording) _recordingBar(),
            _composer(),
            if (_showEmoji) _emojiPanel(),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _replyBar() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.reply, color: BlastColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _replyPreview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() {
              _replyToId = null;
              _replyPreview = '';
            }),
          ),
        ],
      ),
    );
  }

  Widget _recordingBar() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Text('Recording voice message…'),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _recording = false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _recording = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Sending voice messages needs media upload, which is '
                    'not wired yet in this build.',
                  ),
                ),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    final state = context.read<AppState>();
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _showAttachMenu,
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Message',
                border: InputBorder.none,
                filled: false,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: Icon(
              _showEmoji
                  ? Icons.keyboard
                  : Icons.emoji_emotions_outlined,
            ),
            onPressed: () {
              setState(() => _showEmoji = !_showEmoji);
              if (_showEmoji) _focusNode.unfocus();
            },
          ),
          const SizedBox(width: 2),
          _textController.text.trim().isEmpty
              ? IconButton(
                  icon: const Icon(Icons.mic),
                  color: BlastColors.primary,
                  onPressed: () => setState(() => _recording = true),
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: BlastColors.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    color: Colors.white,
                    onPressed: _sending ? null : () => _send(state),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _emojiPanel() {
    const emojis = <String>[
      '😀', '😂', '❤️', '🔥', '👍', '😮', '😢', '🙏',
      '🎉', '🚀', '😍', '🤔', '👏', '💯', '😎', '🥰',
      '😅', '🙌', '✨', '💙', '😴', '🤝', '🎵', '⚡',
    ];
    return Container(
      height: 220,
      color: Theme.of(context).colorScheme.surface,
      child: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () {
              _textController.text += emojis[index];
              setState(() {});
            },
            child: Center(
              child: Text(
                emojis[index],
                style: const TextStyle(fontSize: 26),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _send(AppState state) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final replyToId = _replyToId;
    _textController.clear();
    setState(() {
      _sending = true;
      _replyToId = null;
      _replyPreview = '';
    });
    try {
      await state.sendMessage(widget.chat, text, replyToId: replyToId);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showAttachMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _attachItem(Icons.photo, 'Photo or Video', 'Media upload is not wired yet in this build.'),
              _attachItem(Icons.insert_drive_file, 'File', 'File upload is not wired yet in this build.'),
              _attachItem(Icons.location_on, 'Location', 'Location sharing is not wired yet in this build.'),
              _attachItem(Icons.person, 'Contact', 'Contact sharing is not wired yet in this build.'),
            ],
          ),
        );
      },
    );
  }

  Widget _attachItem(IconData icon, String label, String note) {
    return ListTile(
      leading: Icon(icon, color: BlastColors.primary),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(note)),
        );
      },
    );
  }

  void _showMessageActions(ChatMessage message) {
    final state = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: MessageBubble.quickReactions.map((emoji) {
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        state.toggleReaction(widget.chat, message, emoji);
                      },
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _replyToId = message.id;
                    _replyPreview = message.text;
                  });
                  _focusNode.requestFocus();
                },
              ),
              ListTile(
                leading: const Icon(Icons.forward),
                title: const Text('Forward'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showForwardPicker(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.of(context).pop();
                  Clipboard.setData(ClipboardData(text: message.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
              if (message.isMine)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      await state.deleteMessage(widget.chat, message);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not delete: $e')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showForwardPicker(ChatMessage message) {
    final state = context.read<AppState>();
    final targets = state.chats
        .where((c) => c.id != widget.chat.id)
        .toList();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forward to…'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: targets.isEmpty
                ? const Center(child: Text('No other chats.'))
                : ListView.builder(
                    itemCount: targets.length,
                    itemBuilder: (context, index) {
                      final target = targets[index];
                      return ListTile(
                        leading: BlastAvatar(
                          name: target.title,
                          colorValue: target.colorValue,
                          size: 40,
                        ),
                        title: Text(target.title),
                        onTap: () async {
                          Navigator.of(context).pop();
                          try {
                            await state.forwardMessage(
                              widget.chat,
                              message,
                              target,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Forwarded to ${target.title}',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not forward: $e'),
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _startCall(Chat chat, CallKind kind) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CallScreen(contactName: chat.title, kind: kind),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    final label = diff == 0
        ? 'Today'
        : diff == 1
            ? 'Yesterday'
            : '${date.day}/${date.month}/${date.year}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? BlastColors.darkSurface2
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
