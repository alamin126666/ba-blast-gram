import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/models.dart';
import 'avatars.dart';

/// A Telegram-style message bubble: text, photo, voice, replies,
/// forwards, reactions, edit mark and read ticks. Long-press opens the
/// reaction / action sheet handled by the parent via callbacks.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isGroup,
    required this.onLongPress,
    required this.onReplyTap,
  });

  final ChatMessage message;
  final bool isGroup;
  final VoidCallback onLongPress;
  final VoidCallback onReplyTap;

  static const List<String> quickReactions = <String>[
    '❤️',
    '👍',
    '🔥',
    '😂',
    '😮',
    '😢',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mine = message.isMine;
    final bubbleColor = mine
        ? null
        : (isDark ? BlastColors.darkSurface2 : Colors.white);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!mine && isGroup)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: BlastAvatar(
                name: message.senderName,
                colorValue: 0xFF6C5CE7,
                size: 30,
                fontSize: 11,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: <Widget>[
                GestureDetector(
                  onLongPress: onLongPress,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.76,
                    ),
                    decoration: BoxDecoration(
                      gradient: mine ? BlastColors.bubbleGradient : null,
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(mine ? 16 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 16),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (message.forwardedFrom != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.reply,
                                  size: 15,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    'Forwarded from ${message.forwardedFrom}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: mine
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : BlastColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (message.replyTo != null)
                          GestureDetector(
                            onTap: onReplyTap,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (mine ? Colors.white : BlastColors.primary)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                                border: Border(
                                  left: BorderSide(
                                    color: mine
                                        ? Colors.white
                                        : BlastColors.primary,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Text(
                                message.replyTo!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: mine
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        if (!mine && isGroup)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              message.senderName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: BlastColors.violet,
                              ),
                            ),
                          ),
                        if (message.kind == MessageKind.photo)
                          _PhotoContent(message: message, mine: mine),
                        if (message.kind == MessageKind.voice)
                          _VoiceContent(message: message, mine: mine),
                        if (message.kind == MessageKind.text ||
                            message.kind == MessageKind.photo)
                          Text(
                            message.text,
                            style: TextStyle(
                              fontSize: 15.5,
                              height: 1.35,
                              color: mine
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (message.edited)
                              Text(
                                'edited ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: mine
                                      ? Colors.white.withValues(alpha: 0.75)
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.5,
                                        ),
                                ),
                              ),
                            Text(
                              formatMessageTime(message.time),
                              style: TextStyle(
                                fontSize: 11,
                                color: mine
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                            ),
                            if (mine) ...<Widget>[
                              const SizedBox(width: 4),
                              Icon(
                                message.read
                                    ? Icons.done_all
                                    : Icons.done,
                                size: 15,
                                color: message.read
                                    ? const Color(0xFF7DD3FC)
                                    : Colors.white.withValues(alpha: 0.8),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (message.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? BlastColors.darkSurface2
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        message.reactions.join(' '),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoContent extends StatelessWidget {
  const _PhotoContent({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      height: 150,
      width: 230,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            BlastColors.avatarColorFor(message.id),
            BlastColors.violet,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: <Widget>[
          const Center(
            child: Icon(Icons.photo, color: Colors.white70, size: 40),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                message.mediaLabel ?? 'Photo',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          if (message.mediaCount > 1)
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+${message.mediaCount - 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VoiceContent extends StatelessWidget {
  const _VoiceContent({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final seconds = message.durationSeconds ?? 0;
    final label =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: mine
                  ? Colors.white.withValues(alpha: 0.25)
                  : BlastColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow,
              color: mine ? Colors.white : BlastColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: List<Widget>.generate(18, (i) {
              final heights = <double>[8, 14, 20, 12, 18, 10, 22, 14, 9, 16];
              return Container(
                width: 3,
                height: heights[i % heights.length],
                margin: const EdgeInsets.symmetric(horizontal: 1.2),
                decoration: BoxDecoration(
                  color: mine
                      ? Colors.white.withValues(alpha: 0.85)
                      : BlastColors.primary.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: mine
                  ? Colors.white.withValues(alpha: 0.9)
                  : Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.6,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
