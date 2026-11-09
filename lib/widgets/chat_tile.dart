import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/models.dart';
import 'avatars.dart';

/// One row of the chat list, with swipe actions (pin / delete),
/// unread badge, typing indicator, mute and verified marks, and a
/// staggered entrance animation.
class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.chat,
    required this.index,
    required this.onTap,
    required this.onPin,
    required this.onMute,
    required this.onDelete,
  });

  final Chat chat;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onMute;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + (index % 8) * 45),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: ValueKey<String>('chat-${chat.id}'),
        background: Container(
          color: BlastColors.primary,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: Icon(
            chat.pinned ? Icons.push_pin_outlined : Icons.push_pin,
            color: Colors.white,
          ),
        ),
        secondaryBackground: Container(
          color: const Color(0xFFEF4444),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onPin();
            return false;
          }
          return true;
        },
        onDismissed: (_) => onDelete(),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: <Widget>[
                BlastAvatar(
                  name: chat.title,
                  colorValue: chat.colorValue,
                  size: 52,
                  isOnline: chat.isOnline,
                  isChannel: chat.isChannel,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    chat.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (chat.verified)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.verified,
                                      size: 16,
                                      color: BlastColors.primary,
                                    ),
                                  ),
                                if (chat.muted)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.volume_off,
                                      size: 15,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatChatTime(chat.lastTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: chat.unread > 0
                                  ? BlastColors.primary
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: chat.typing
                                ? const Text(
                                    'typing…',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                      color: BlastColors.primary,
                                    ),
                                  )
                                : Text(
                                    chat.lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                          ),
                          if (chat.unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: chat.muted
                                    ? (isDark
                                          ? const Color(0xFF3A4A5A)
                                          : const Color(0xFFCBD5E1))
                                    : BlastColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                chat.unread > 99 ? '99+' : '${chat.unread}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else if (chat.pinned)
                            Icon(
                              Icons.push_pin,
                              size: 15,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
