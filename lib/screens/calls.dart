import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/avatars.dart';
import '../widgets/stories_row.dart';

/// Calls: recent call log + the active call screen.
///
/// Voice/video calling over the Telegram network needs the TDLib native
/// library, which is not in this build — the call screen says so
/// honestly instead of pretending a call connected. The log itself is
/// real local data: every call attempt from this device is recorded.
class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key, this.inTab = false});

  final bool inTab;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final calls = state.calls;
    final content = calls.isEmpty
        ? const EmptyState(
            icon: Icons.call_outlined,
            title: 'No calls yet',
            subtitle:
                'Voice and video calls over the Telegram network need the '
                'TDLib native library, which is not in this build. '
                'Call attempts you make are logged here.',
          )
        : ListView.builder(
            itemCount: calls.length,
            itemBuilder: (context, index) {
              final call = calls[index];
              final missed = call.direction == CallDirection.missed;
              return ListTile(
                leading: BlastAvatar(
                  name: call.contactName,
                  colorValue: call.colorValue,
                  size: 48,
                ),
                title: Text(
                  call.contactName,
                  style: TextStyle(
                    color: missed ? Colors.red : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${missed ? 'Missed' : call.direction == CallDirection.incoming ? 'Incoming' : 'Outgoing'} • ${formatCallTime(call.time)}${call.duration != null ? ' • ${_formatDuration(call.duration!)}' : ''}',
                ),
                trailing: IconButton(
                  icon: Icon(
                    call.kind == CallKind.video
                        ? Icons.videocam
                        : Icons.call,
                    color: BlastColors.primary,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CallScreen(
                        contactName: call.contactName,
                        kind: call.kind,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
    if (inTab) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Calls')),
      body: content,
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.contactName,
    required this.kind,
  });

  final String contactName;
  final CallKind kind;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _showLimit = false;
  bool _muted = false;
  bool _speaker = false;
  bool _videoOff = false;
  Timer? _timer;
  final int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showLimit = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _endCall() {
    context.read<AppState>().logCall(
      CallRecord(
        id: 'k-${DateTime.now().millisecondsSinceEpoch}',
        contactName: widget.contactName,
        kind: widget.kind,
        direction: CallDirection.outgoing,
        time: DateTime.now(),
        duration: Duration(seconds: _seconds),
        colorValue: BlastColors.avatarColorFor(widget.contactName).toARGB32(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF0E1621), Color(0xFF1E2C3A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 48),
              BlastAvatar(
                name: widget.contactName,
                colorValue: BlastColors.avatarColorFor(
                  widget.contactName,
                ).toARGB32(),
                size: 110,
                fontSize: 38,
              ),
              const SizedBox(height: 20),
              Text(
                widget.contactName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _showLimit
                    ? 'Could not connect'
                    : 'Calling… (${widget.kind == CallKind.video ? 'video' : 'voice'})',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              if (_showLimit)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Voice/video calls over the Telegram network need the '
                    'TDLib native library, which is not in this build. '
                    'Messaging, groups and channels work over the real '
                    'Telegram API. This attempt is logged in Calls.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, height: 1.5),
                  ),
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _CallControl(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    label: _muted ? 'Unmute' : 'Mute',
                    active: _muted,
                    onTap: () => setState(() => _muted = !_muted),
                  ),
                  _CallControl(
                    icon: Icons.volume_up,
                    label: 'Speaker',
                    active: _speaker,
                    onTap: () => setState(() => _speaker = !_speaker),
                  ),
                  if (widget.kind == CallKind.video)
                    _CallControl(
                      icon: _videoOff
                          ? Icons.videocam_off
                          : Icons.videocam,
                      label: 'Video',
                      active: _videoOff,
                      onTap: () => setState(() => _videoOff = !_videoOff),
                    ),
                  _CallControl(
                    icon: Icons.call_end,
                    label: 'End',
                    active: false,
                    background: Colors.red,
                    onTap: _endCall,
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.background,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: background ??
                  (active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.18)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: background != null
                  ? Colors.white
                  : active
                      ? Colors.black87
                      : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
