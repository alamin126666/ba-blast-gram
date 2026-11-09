import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/models.dart';
import 'avatars.dart';

/// Horizontal stories row shown on top of the chat list.
class StoriesRow extends StatelessWidget {
  const StoriesRow({
    super.key,
    required this.stories,
    required this.onStoryTap,
    required this.onAddStory,
  });

  final List<Story> stories;
  final ValueChanged<Story> onStoryTap;
  final VoidCallback onAddStory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: stories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StoryItem(
              label: 'My Story',
              isMine: true,
              viewed: false,
              colorValue: 0xFF1C93D1,
              initials: '+',
              onTap: onAddStory,
            );
          }
          final story = stories[index - 1];
          return _StoryItem(
            label: story.userName,
            isMine: false,
            viewed: story.viewed,
            colorValue: story.colorValue,
            initials: story.initials,
            onTap: () => onStoryTap(story),
          );
        },
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  const _StoryItem({
    required this.label,
    required this.isMine,
    required this.viewed,
    required this.colorValue,
    required this.initials,
    required this.onTap,
  });

  final String label;
  final bool isMine;
  final bool viewed;
  final int colorValue;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ringColor = viewed
        ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
        : null;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          children: <Widget>[
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: viewed ? null : BlastColors.brandGradient,
                color: ringColor,
              ),
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface,
                ),
                padding: const EdgeInsets.all(2),
                child: isMine
                    ? Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: BlastColors.brandGradient,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 26,
                        ),
                      )
                    : BlastAvatar(
                        name: label,
                        colorValue: colorValue,
                        size: 52,
                        fontSize: 17,
                      ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 62,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic empty state for lists that legitimately have no data yet
/// (no chats, no stories, no calls) — honest, never fake content.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                gradient: BlastColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
