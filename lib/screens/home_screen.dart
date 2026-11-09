import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../config/telegram_config.dart';
import '../state/app_state.dart';
import '../widgets/avatars.dart';
import '../widgets/chat_tile.dart';
import '../widgets/stories_row.dart';
import 'calls.dart';
import 'chat_screen.dart';
import 'contacts_screens.dart';
import 'settings_screens.dart';
import 'stories.dart';

/// Home shell: drawer + folder tabs + stories row + chat list,
/// with bottom navigation across Chats / Calls / Contacts / Settings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _navIndex = 0;
  late final TabController _tabController;

  static const List<ChatFolder> _folders = <ChatFolder>[
    ChatFolder.all,
    ChatFolder.personal,
    ChatFolder.groups,
    ChatFolder.channels,
    ChatFolder.unread,
  ];

  static const List<String> _folderLabels = <String>[
    'All',
    'Personal',
    'Groups',
    'Channels',
    'Unread',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _folders.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<AppState>().setFolder(_folders[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _ChatsTab(tabController: _tabController, folderLabels: _folderLabels),
      const CallsScreen(inTab: true),
      const ContactsScreen(inTab: true),
      const SettingsScreen(inTab: true),
    ];
    return Scaffold(
      appBar: _navIndex == 0
          ? AppBar(
              title: const Text('BA BLAST GRAM'),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SearchScreen(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showMoreMenu(context),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _folderLabels
                    .map((label) => Tab(text: label))
                    .toList(),
              ),
            )
          : AppBar(
              title: Text(
                <String>['Chats', 'Calls', 'Contacts', 'Settings'][_navIndex],
              ),
            ),
      drawer: _navIndex == 0 ? _BlastDrawer(onNavigate: _goToTab) : null,
      body: IndexedStack(index: _navIndex, children: pages),
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NewMessageScreen(),
                ),
              ),
              child: const Icon(Icons.edit),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Contacts'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _goToTab(int index) {
    Navigator.of(context).pop();
    setState(() => _navIndex = index);
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text('New Group'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NewGroupScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.campaign),
                title: const Text('New Channel'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NewChannelScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark),
                title: const Text('Saved Messages'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SavedMessagesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab({required this.tabController, required this.folderLabels});

  final TabController tabController;
  final List<String> folderLabels;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final chats = state.visibleChats;
    return RefreshIndicator(
      onRefresh: () async {
        await state.loadChats();
      },
      child: Column(
        children: <Widget>[
          StoriesRow(
            stories: state.stories,
            onStoryTap: (story) {
              state.markStoryViewed(story);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StoryViewerScreen(
                    stories: state.stories,
                    initialIndex: state.stories.indexOf(story),
                  ),
                ),
              );
            },
            onAddStory: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Posting stories is not wired yet in this build.',
                  ),
                ),
              );
            },
          ),
          if (state.authError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                state.authError!,
                style: const TextStyle(fontSize: 13, color: Colors.red),
              ),
            ),
          Expanded(
            child: state.loadingChats && chats.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : chats.isEmpty
                    ? EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No chats yet',
                        subtitle:
                            'Your Telegram chats will appear here once you '
                            'log in. Pull down to refresh.',
                        actionLabel: 'Refresh',
                        onAction: () => state.loadChats(),
                      )
                    : ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          return ChatTile(
                            chat: chat,
                            index: index,
                            onTap: () {
                              state.markChatRead(chat);
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ChatScreen(chat: chat),
                                ),
                              );
                            },
                            onPin: () => state.togglePin(chat),
                            onMute: () => state.toggleMute(chat),
                            onDelete: () {
                              state.deleteChat(chat);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${chat.title} deleted'),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _BlastDrawer extends StatelessWidget {
  const _BlastDrawer({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: BlastColors.brandGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  MeAvatar(profile: me, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    me.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    me.phone ?? state.phoneNumber,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('New Group'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NewGroupScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('New Channel'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NewChannelScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('Saved Messages'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SavedMessagesScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.call),
              title: const Text('Calls'),
              onTap: () => onNavigate(1),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Contacts'),
              onTap: () => onNavigate(2),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () => onNavigate(3),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About BA BLAST GRAM'),
              onTap: () {
                Navigator.of(context).pop();
                showAboutDialog(
                  context: context,
                  applicationName: TelegramConfig.appName,
                  applicationVersion: '1.0.0',
                  applicationLegalese:
                      'BA BLAST GRAM is an unofficial Telegram client. '
                      'It connects to Telegram with the official Telegram '
                      'API (MTProto) using the owner\'s api_id/api_hash. '
                      'Not affiliated with or endorsed by Telegram.',
                  children: const <Widget>[
                    SizedBox(height: 8),
                    Text('Built with Flutter & Dart.'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
