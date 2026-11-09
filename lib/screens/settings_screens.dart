import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../config/telegram_config.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/avatars.dart';
import '../widgets/stories_row.dart';
import 'chat_screen.dart';

/// Settings, profile editing, chat info, global search and Saved Messages.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.inTab = false});

  final bool inTab;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me;
    final content = ListView(
      children: <Widget>[
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                MeAvatar(profile: me, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        me.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        me.phone ?? state.phoneNumber,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      if (me.username != null)
                        Text(
                          '@${me.username}',
                          style: const TextStyle(
                            color: BlastColors.primary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.edit, size: 20),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode),
          title: const Text('Dark mode'),
          subtitle: const Text('Premium dark theme'),
          value: state.isDarkMode,
          onChanged: (_) => state.toggleTheme(),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications),
          title: const Text('Notifications'),
          subtitle: const Text('Message notifications'),
          value: state.notificationsEnabled,
          onChanged: state.toggleNotifications,
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.lock),
          title: const Text('Privacy and Security'),
          subtitle: const Text('Blocked users, passcode, sessions'),
          onTap: () => _showInfo(
            context,
            'Privacy and Security',
            'Privacy controls (blocked users, active sessions, passcode '
                'lock) are managed through the Telegram API and arrive in '
                'a later update. Your login itself is protected by '
                'Telegram OTP + 2FA.',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.storage),
          title: const Text('Data and Storage'),
          subtitle: const Text('Session, cache, downloads'),
          onTap: () => _showInfo(
            context,
            'Data and Storage',
            'Your Telegram session is stored locally in an encrypted '
                'mtflute session file. Media is streamed from Telegram '
                'and cached by the client. Storage management arrives in '
                'a later update.',
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            'TELEGRAM API',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        ListTile(
          leading: Icon(
            state.apiConfigured ? Icons.verified : Icons.warning_amber,
            color: state.apiConfigured ? Colors.green : Colors.amber,
          ),
          title: Text(
            state.apiConfigured
                ? 'Real Telegram — connected with owner\'s API keys'
                : 'API not configured',
          ),
          subtitle: const Text(
            'MTProto layer ${TelegramConfig.apiLayer} • mtflute (pure Dart)\n'
            'End users log in with phone + OTP only — no keys needed.',
          ),
          onTap: () => _showInfo(
            context,
            'How the API keys work',
            TelegramConfig.liveSetupSteps,
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About BA BLAST GRAM'),
          subtitle: const Text('Version 1.0.0 • Flutter & Dart'),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: TelegramConfig.appName,
            applicationVersion: '1.0.0',
            applicationLegalese:
                'BA BLAST GRAM is an unofficial Telegram client. It '
                'connects to Telegram with the official Telegram API '
                '(MTProto) using the owner\'s api_id/api_hash. '
                'Not affiliated with or endorsed by Telegram.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Log out',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => _confirmLogout(context, state),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            'BA BLAST GRAM • ${TelegramConfig.packageName}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
    if (inTab) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: content,
    );
  }

  void _showInfo(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body, style: const TextStyle(height: 1.5)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, AppState state) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'You will need your phone number and OTP to log in again.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                state.logout();
              },
              child: const Text('Log out', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final me = context.read<AppState>().me;
    _nameController = TextEditingController(text: me.name);
    _bioController = TextEditingController(text: me.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Center(child: MeAvatar(profile: me, size: 96)),
          const SizedBox(height: 20),
          Center(
            child: Text(
              me.phone ?? state.phoneNumber,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (me.username != null)
            Center(
              child: Text(
                '@${me.username}',
                style: const TextStyle(color: BlastColors.primary),
              ),
            ),
          const SizedBox(height: 28),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bio',
              prefixIcon: Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Note: in this build the name/bio change is shown in the app '
            'only. Pushing it to Telegram\'s servers is a later update.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () async {
                await state.updateProfile(
                  name: _nameController.text,
                  bio: _bioController.text,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated')),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatInfoScreen extends StatelessWidget {
  const ChatInfoScreen({super.key, required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final messages = state.cachedMessages(chat.id);
    final photos = messages
        .where((m) => m.kind == MessageKind.photo)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Info')),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                BlastAvatar(
                  name: chat.title,
                  colorValue: chat.colorValue,
                  size: 96,
                  isChannel: chat.isChannel,
                ),
                const SizedBox(height: 14),
                Text(
                  chat.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chat.isGroup
                      ? '${chat.members} members'
                      : chat.isChannel
                          ? 'channel${chat.username != null ? ' • @${chat.username}' : ''}'
                          : chat.isOnline
                              ? 'online'
                              : 'last seen recently',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.volume_off),
            title: const Text('Mute notifications'),
            value: chat.muted,
            onChanged: (_) => state.toggleMute(chat),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.push_pin),
            title: const Text('Pin chat'),
            value: chat.pinned,
            onChanged: (_) => state.togglePin(chat),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Shared media'),
            subtitle: Text('${photos.length} photo(s) in this conversation'),
          ),
          if (photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          BlastColors.avatarColorFor(photos[index].id),
                          BlastColors.violet,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.photo,
                      color: Colors.white70,
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text(
              'Delete chat',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              state.deleteChat(chat);
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _query.toLowerCase();
    final chats = q.isEmpty
        ? <Chat>[]
        : state.chats
              .where(
                (c) =>
                    c.title.toLowerCase().contains(q) ||
                    c.lastMessage.toLowerCase().contains(q),
              )
              .toList();
    final contacts = q.isEmpty
        ? <Contact>[]
        : state.contacts
              .where((c) => c.name.toLowerCase().contains(q))
              .toList();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search chats, contacts…',
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: _query.isEmpty
          ? const Center(child: Text('Search your Telegram chats.'))
          : ListView(
              children: <Widget>[
                if (chats.isNotEmpty) ...<Widget>[
                  const _SectionHeader('Chats'),
                  ...chats.map(
                    (chat) => ListTile(
                      leading: BlastAvatar(
                        name: chat.title,
                        colorValue: chat.colorValue,
                        size: 44,
                      ),
                      title: Text(chat.title),
                      subtitle: Text(
                        chat.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChatScreen(chat: chat),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (contacts.isNotEmpty) ...<Widget>[
                  const _SectionHeader('Contacts'),
                  ...contacts.map(
                    (contact) => ListTile(
                      leading: BlastAvatar(
                        name: contact.name,
                        colorValue: contact.colorValue,
                        size: 44,
                      ),
                      title: Text(contact.name),
                      subtitle: Text(contact.username ?? contact.phone ?? ''),
                    ),
                  ),
                ],
                if (chats.isEmpty && contacts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Nothing found.')),
                  ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class SavedMessagesScreen extends StatelessWidget {
  const SavedMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final index = state.chats.indexWhere((c) => c.type == ChatType.saved);
    if (index == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved Messages')),
        body: const EmptyState(
          icon: Icons.bookmark_outline,
          title: 'No Saved Messages yet',
          subtitle:
              'Your Saved Messages chat appears here once Telegram returns '
              'it. Forward any message to Saved Messages to keep it.',
        ),
      );
    }
    final chat = state.chats[index];
    return ChatScreen(chat: chat);
  }
}
