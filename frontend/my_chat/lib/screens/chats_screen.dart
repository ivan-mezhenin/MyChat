import 'package:flutter/material.dart';
import 'package:my_chat/services/chat_service.dart';
import 'package:my_chat/services/websocket_service.dart';
import 'package:my_chat/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatsScreen extends StatefulWidget {
  final List<dynamic> chats;
  final String userUID;

  const ChatsScreen({
    Key? key,
    required this.chats,
    required this.userUID,
  }) : super(key: key);

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatService _chatService = ChatService();
  final WebSocketService _webSocketService = WebSocketService();
  List<dynamic> _chats = [];
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _chats = widget.chats;
    _loadTokenAndConnect();
    _setupWebSocketListeners();
  }

  Future<void> _loadTokenAndConnect() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    
    if (_authToken != null) {
      await _webSocketService.connect(_authToken!);
      _loadInitialData();
    }
  }

  void _setupWebSocketListeners() {
    _webSocketService.onNewMessage = (message) {
      _updateChatLastMessage(message);
    };
  }

  void _updateChatLastMessage(Map<String, dynamic> message) {
    final chatId = message['chat_id'];
    final text = message['text'];
    final timestamp = DateTime.parse(message['timestamp']);
    
    setState(() {
      for (var chat in _chats) {
        if (chat['id'] == chatId) {
          chat['last_message'] = text;
          chat['last_message_time'] = timestamp;
          break;
        }
      }
    });
  }

  Future<void> _exitFromAccount() async {
    if (_authToken == null) return;

    try {
      final data = await _chatService.getInitialData(_authToken!);
      if (data['success'] == true) {
        setState(() {
          _chats = data['chats'];
        });
      }
    } catch (e) {
      print('Error loading chats: $e');
    }
  }

  void _navigateToChat(Map<String, dynamic> chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chat['id'],
          chatName: chat['name'],
          userUID: widget.userUID,
          webSocketService: _webSocketService,
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Вчера';
    } else {
      return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _exitFromAccount,
          ),
        ],
      ),
      body: _chats.isEmpty
          ? const Center(
              child: Text(
                'У вас пока нет чатов',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                final lastMessage = chat['last_message']?.toString() ?? '';
                final lastMessageTime = chat['last_message_time'] != null
                    ? DateTime.parse(chat['last_message_time'].toString())
                    : null;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      chat['name']?.toString().substring(0, 1).toUpperCase() ?? 'C',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    chat['name']?.toString() ?? 'Чат',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    lastMessage.isNotEmpty ? lastMessage : 'Нет сообщений',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: lastMessageTime != null
                      ? Text(
                          _formatTime(lastMessageTime),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                  onTap: () => _navigateToChat(chat),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    super.dispose();
  }
}