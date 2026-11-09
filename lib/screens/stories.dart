import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/avatars.dart';

/// Full-screen story viewer with progress bars and tap navigation.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  final List<Story> stories;
  final int initialIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progressController;
  late int _index;
  Timer? _advanceTimer;

  static const Duration _storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _pageController = PageController(initialPage: _index);
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    );
    _startStory();
  }

  void _startStory() {
    _advanceTimer?.cancel();
    _progressController.reset();
    _progressController.forward();
    context.read<AppState>().markStoryViewed(widget.stories[_index]);
    _advanceTimer = Timer(_storyDuration, _next);
  }

  void _next() {
    if (_index < widget.stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previous() {
    if (_index > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _pageController,
            itemCount: widget.stories.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _startStory();
            },
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              return GestureDetector(
                onTapUp: (details) {
                  final width = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx > width * 0.6) {
                    _next();
                  } else if (details.globalPosition.dx < width * 0.4) {
                    _previous();
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Color(story.colorValue),
                        BlastColors.violet,
                        const Color(0xFF0E1621),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        BlastAvatar(
                          name: story.userName,
                          colorValue: story.colorValue,
                          size: 110,
                          fontSize: 38,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          story.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Story',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Row(
                    children: List<Widget>.generate(widget.stories.length, (i) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: i < _index
                              ? Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                )
                              : i == _index
                                  ? AnimatedBuilder(
                                      animation: _progressController,
                                      builder: (context, child) {
                                        return Container(
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: FractionallySizedBox(
                                              widthFactor:
                                                  _progressController.value,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
                  child: Row(
                    children: <Widget>[
                      BlastAvatar(
                        name: widget.stories[_index].userName,
                        colorValue: widget.stories[_index].colorValue,
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.stories[_index].userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              formatChatTime(widget.stories[_index].time),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
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
