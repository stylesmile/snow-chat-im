import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'profile_screen.dart';

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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.chat), label: l10n.chat),
          BottomNavigationBarItem(icon: const Icon(Icons.people), label: l10n.contacts),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: l10n.profile),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pop();
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
          }
        },
      ),
    );
  }
}
