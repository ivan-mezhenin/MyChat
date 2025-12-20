import 'package:flutter/material.dart';
import 'package:my_chat/screens/contacts_screen.dart';
import 'package:my_chat/screens/create_group_chat_screen.dart';
import 'package:my_chat/services/chat_service.dart';
import 'package:my_chat/services/websocket_service.dart';
import 'package:my_chat/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_chat/screens/authentication_screen.dart';

class ChatsScreen extends StatefulWidget {
  final List<Chat> chats;
  final String userUID;
  final WebSocketService webSocketService; 
  

  const ChatsScreen({
    super.key,
    required this.chats,
    required this.userUID,
    required this.webSocketService,
  });

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late ChatService _chatService;
  List<Chat> _chats = [];
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _chats = widget.chats;
    _setupWebSocketListeners();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
      
      _chatService = ChatService(prefs: prefs);
      await _loadInitialData();
      }
    catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

   void _navigateToContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactsScreen(userUID: widget.userUID,  webSocketService: widget.webSocketService,),
      ),
    );
  }

  void _navigateToCreateGroupChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGroupChatScreen(userUID: widget.userUID, webSocketService: widget.webSocketService,),
      ),
    );
  }

  void _setupWebSocketListeners() {
    widget.webSocketService.onNewMessage = (message) {
      _updateChatLastMessage(message);
    };

    widget.webSocketService.onNewChat = (chatData) {
      _addNewChat(chatData);
    };
  }

    void _addNewChat(Map<String, dynamic> chatData) {
    if (!mounted) return;
    
    final chat = Chat(
      id: chatData['chat_id'] as String,
      name: chatData['name'] as String,
      participantIds: List<String>.from(chatData['participants'] as List),
      lastMessage: null,
      lastMessageTime: null,
    );
    
    setState(() {
      _chats.insert(0, chat);
    });
    }


  void _updateChatLastMessage(Map<String, dynamic> message) {
    if (!mounted) return;
    
    final chatId = message['chat_id'] as String;
    final text = message['text'] as String;
    final timestamp = DateTime.parse(message['timestamp'] as String);
    
    setState(() {
      for (int i = 0; i < _chats.length; i++) {
        final chat = _chats[i];
        if (chat.id == chatId) {
          _chats[i] = Chat(
            id: chat.id,
            name: chat.name,
            lastMessage: text,
            lastMessageTime: timestamp,
            participantIds: chat.participantIds,
          );

          final updatedChat = _chats.removeAt(i);
          _chats.insert(0, updatedChat);
          break;
        }
      }
    });
  }

  Future<void> _loadInitialData() async {
    if (_authToken == null) return;

    try {
      final response = await _chatService.getInitialData();
      if (response.success && mounted) {
        final List<Chat> chats = response.data!;
        setState(() {
          _chats = chats;
        });
      }
    } catch (e) {
      debugPrint('Error loading chats: $e');
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _performLogout();
    }
  }

  Future<void> _performLogout() async {
    try {
      widget.webSocketService.disconnect();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthenticationScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthenticationScreen(),
          ),
          (route) => false,
        );
      }
    }
  }

  void _navigateToChat(Chat chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chat.id,
          chatName: chat.name,
          userUID: widget.userUID,
          webSocketService: widget.webSocketService,
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
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Выйти из аккаунта',
          ),
          IconButton(
            icon: const Icon(Icons.contacts),
            onPressed: _navigateToContacts,
            tooltip: 'Contacts',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGroupChat,
        tooltip: 'New group chat',
        child: const Icon(Icons.add_comment),
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
                final lastMessage = chat.lastMessage ?? '';
                final lastMessageTime = chat.lastMessageTime;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      chat.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    chat.name,
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
   widget.webSocketService.onNewMessage = null;
   widget.webSocketService.onNewChat = null;
    super.dispose();
  }
}