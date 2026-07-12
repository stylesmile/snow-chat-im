import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.contacts)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchUser,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: 0, // TODO: Load from API
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return const ListTile(title: Text('No contacts'));
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.person_add),
        label: Text(l10n.addFriend),
      ),
    );
  }
}
