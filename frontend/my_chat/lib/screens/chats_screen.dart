// lib/screens/chats_screen.dart
import 'package:flutter/material.dart';
import 'package:my_chat/services/auth_service.dart';
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
  final AuthService _authService = AuthService();
  List<dynamic> _chats = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _chats = widget.chats;
    _loadChatsPeriodically();
  }

  void _loadChatsPeriodically() {
    // Загружаем чаты каждые 30 секунд
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _refreshChats();
        _loadChatsPeriodically();
      }
    });
  }

  Future<void> _refreshChats() async {
    final token = widget.authToken;
    if (token.isEmpty) return;

    final result = await _authService.getChats(token);
    if (result['success'] == true && mounted) {
      setState(() {
        _chats = result['chats'];
      });
    }
  }

  void _logout() async {
    setState(() {
      _isLoading = true;
    });

    await _authService.logout();

    if (!mounted) return;
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthenticationScreen()),
      (route) => false,
    );
  }

  void _openChat(Map<String, dynamic> chat) {
    // TODO: Переход в конкретный чат
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Открываем чат: ${chat['name']}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои чаты'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Выйти',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshChats,
        child: _chats.isEmpty
            ? const Center(
                child: Text(
                  'У вас пока нет чатов',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: _chats.length,
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  return _buildChatItem(chat);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Создание нового чата
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
          chat['name'][0],
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