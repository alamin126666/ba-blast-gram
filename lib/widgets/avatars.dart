import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../models/models.dart';

/// Format a chat timestamp the Telegram way: time today, "Yesterday",
/// weekday within the week, otherwise a short date.
String formatChatTime(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return DateFormat('HH:mm').format(time);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('EEEE').format(time);
  return DateFormat('dd/MM/yyyy').format(time);
}

String formatMessageTime(DateTime time) => DateFormat('HH:mm').format(time);

String formatCallTime(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  if (today.difference(day).inDays == 0) {
    return 'Today, ${DateFormat('HH:mm').format(time)}';
  }
  return DateFormat('dd MMM, HH:mm').format(time);
}

/// Gradient avatar circle with initials and an optional online dot.
class BlastAvatar extends StatelessWidget {
  const BlastAvatar({
    super.key,
    required this.name,
    required this.colorValue,
    this.size = 52,
    this.isOnline = false,
    this.isChannel = false,
    this.fontSize,
  });

  final String name;
  final int colorValue;
  final double size;
  final bool isOnline;
  final bool isChannel;
  final double? fontSize;

String get _initials => initialsFor(name);

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: isChannel ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: isChannel ? BorderRadius.circular(size * 0.28) : null,
            gradient: LinearGradient(
              colors: <Color>[color, color.withValues(alpha: 0.65)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: isChannel
              ? Icon(Icons.campaign, color: Colors.white, size: size * 0.5)
              : Text(
                  _initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize ?? size * 0.36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The BA BLAST GRAM logo: gradient rounded square + paper plane.
class BlastLogo extends StatelessWidget {
  const BlastLogo({super.key, this.size = 96, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: BlastColors.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: BlastColors.primary.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(
            Icons.send_rounded,
            color: Colors.white,
            size: size * 0.52,
          ),
        ),
        if (showName) ...<Widget>[
          const SizedBox(height: 18),
          Text(
            'BA BLAST GRAM',
            style: TextStyle(
              fontSize: size * 0.26,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fast. Secure. Blast it.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Small gradient avatar used for the signed-in user in drawers/headers.
class MeAvatar extends StatelessWidget {
  const MeAvatar({super.key, required this.profile, this.size = 44});

  final UserProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    return BlastAvatar(
      name: profile.name,
      colorValue: profile.colorValue,
      size: size,
      isOnline: true,
    );
  }
}
