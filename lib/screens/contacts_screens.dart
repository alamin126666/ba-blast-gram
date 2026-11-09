import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/avatars.dart';
import '../widgets/stories_row.dart';
import 'chat_screen.dart';

/// Contacts list (tab + new-message screen), New Group and New Channel.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, this.inTab = false});

  final bool inTab;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final contacts = state.contacts
        .where(
          (c) =>
              _query.isEmpty ||
              c.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    final content = Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search contacts',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: contacts.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  title: 'No contacts yet',
                  subtitle:
                      'Your Telegram contacts appear here after you log in. '
                      'Contacts are the people from your Telegram dialogs.',
                  actionLabel: 'Refresh',
                  onAction: () => state.loadContacts(),
                )
              : ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ListTile(
                      leading: BlastAvatar(
                        name: contact.name,
                        colorValue: contact.colorValue,
                        size: 48,
                        isOnline: contact.isOnline,
                      ),
                      title: Text(contact.name),
                      subtitle: Text(
                        contact.isOnline
                            ? 'online'
                            : contact.lastSeen.isEmpty
                                ? (contact.username ?? contact.phone ?? '')
                                : contact.lastSeen,
                      ),
                      onTap: () => _openChat(context, state, contact),
                    );
                  },
                ),
        ),
      ],
    );
    if (widget.inTab) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: content,
    );
  }

  void _openChat(BuildContext context, AppState state, Contact contact) {
    final index = state.chats.indexWhere((c) => c.id == contact.id);
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No conversation with this contact yet.'),
        ),
      );
      return;
    }
    final chat = state.chats[index];
    state.markChatRead(chat);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatScreen(chat: chat)),
    );
  }
}

class NewMessageScreen extends StatelessWidget {
  const NewMessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Message')),
      body: Column(
        children: <Widget>[
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: BlastColors.primary,
              child: Icon(Icons.group_add, color: Colors.white),
            ),
            title: const Text('New Group'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NewGroupScreen()),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: BlastColors.violet,
              child: Icon(Icons.campaign, color: Colors.white),
            ),
            title: const Text('New Channel'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NewChannelScreen(),
              ),
            ),
          ),
          const Divider(),
          const Expanded(child: ContactsScreen(inTab: true)),
        ],
      ),
    );
  }
}

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final contacts = state.contacts;
    return Scaffold(
      appBar: AppBar(title: const Text('New Group')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'e.g. BA Blast Community',
                prefixIcon: Icon(Icons.group),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add members',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? const Center(child: Text('No contacts to add yet.'))
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final selected = _selected.contains(contact.id);
                      return CheckboxListTile(
                        secondary: BlastAvatar(
                          name: contact.name,
                          colorValue: contact.colorValue,
                          size: 44,
                        ),
                        title: Text(contact.name),
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(contact.id);
                            } else {
                              _selected.remove(contact.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Give your group a name.'),
                      ),
                    );
                    return;
                  }
                  final members = contacts
                      .where((c) => _selected.contains(c.id))
                      .toList();
                  final chat = state.createGroup(name, members);
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(chat: chat),
                    ),
                  );
                },
                child: const Text('Create Group'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NewChannelScreen extends StatefulWidget {
  const NewChannelScreen({super.key});

  @override
  State<NewChannelScreen> createState() => _NewChannelScreenState();
}

class _NewChannelScreenState extends State<NewChannelScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('New Channel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Channel name',
                hintText: 'e.g. Blast News',
                prefixIcon: Icon(Icons.campaign),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What is this channel about?',
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Channels broadcast to unlimited subscribers. Only admins can post.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Spacer(),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Give your channel a name.'),
                      ),
                    );
                    return;
                  }
                  final chat = state.createChannel(
                    name,
                    _descController.text.trim(),
                  );
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(chat: chat),
                    ),
                  );
                },
                child: const Text('Create Channel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
