// lib/screens/chats_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_chat/screens/authentication_screen.dart';

class ChatsScreen extends StatefulWidget {
  final List<dynamic> chats;
  final String userUID;
  final String authToken;

  const ChatsScreen({
    super.key,
    required this.chats,
    required this.userUID,
    required this.authToken,
  });

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthenticationScreen()),
    );
  }

  void _openChat(Map<String, dynamic> chat) {
    // TODO: В будущем - переход в конкретный чат
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои чаты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: widget.chats.isEmpty
          ? const Center(
              child: Text(
                'У вас пока нет чатов',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: widget.chats.length,
              itemBuilder: (context, index) {
                final chat = widget.chats[index];
                return _buildChatItem(chat);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: В будущем - создание нового чата
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Text(
          chat['name'][0], // Первая буква названия чата
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        chat['name'] ?? 'Без названия',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: chat['last_message'] != null
          ? Text(
              chat['last_message']!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : const Text('Нет сообщений'),
      trailing: chat['last_message_time'] != null
          ? Text(
              _formatTime(chat['last_message_time']!),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            )
          : null,
      onTap: () => _openChat(chat),
    );
  }

  String _formatTime(String timeString) {
    try {
      final time = DateTime.parse(timeString);
      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inDays == 0) {
        return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Вчера';
      } else {
        return '${time.day}.${time.month}';
      }
    } catch (e) {
      return '';
    }
  }
}