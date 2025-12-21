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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _chats = widget.chats;
    _initializeServices();
    _setupWebSocketListeners();
    _printDebug('ChatsScreen initialized with ${_chats.length} chats');
  }

  Future<void> _initializeServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
      
      _chatService = ChatService(prefs: prefs);
      await _loadInitialData();
    } catch (e, stackTrace) {
      _printDebug('Error initializing services: $e\n$stackTrace');
    }
  }

   void _navigateToContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactsScreen(
          userUID: widget.userUID,  
          webSocketService: widget.webSocketService,
        ),
      ),
    ).then((_) {
      _loadInitialData();
    });
  }

  void _navigateToCreateGroupChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGroupChatScreen(
          userUID: widget.userUID, 
          webSocketService: widget.webSocketService,
        ),
      ),
    ).then((_) {
      _loadInitialData();
    });
  }

  void _setupWebSocketListeners() {
    _printDebug('Setting up WebSocket listeners');
    
    widget.webSocketService.onNewMessage = null;
    widget.webSocketService.onNewChat = null;
    
    widget.webSocketService.onNewMessage = (message) {
      _printDebug('New message received: ${message['chat_id']}');
      _updateChatLastMessage(message);
    };

    widget.webSocketService.onNewChat = (chatData) {
      _printDebug('New chat created: ${chatData['chat_id']}');
      _addNewChat(chatData);
    };
  }

  void _addNewChat(Map<String, dynamic> chatData) {
    if (!mounted) return;
    
    try {
      final chatId = chatData['chat_id'] as String;
      final chatName = chatData['name'] as String;
      final participants = List<String>.from(chatData['participants'] as List);
      
      _printDebug('Adding new chat: $chatId ($chatName)');
      
      final existingIndex = _chats.indexWhere((chat) => chat.id == chatId);
      
      if (existingIndex >= 0) {
        setState(() {
          _chats[existingIndex] = Chat(
            id: chatId,
            name: chatName,
            participantIds: participants,
            lastMessage: _chats[existingIndex].lastMessage,
            lastMessageTime: _chats[existingIndex].lastMessageTime,
          );
          
          final chat = _chats.removeAt(existingIndex);
          _chats.insert(0, chat);
        });
      } else {
        final newChat = Chat(
          id: chatId,
          name: chatName,
          participantIds: participants,
          lastMessage: null,
          lastMessageTime: null,
        );
        
        setState(() {
          _chats.insert(0, newChat);
        });
      }
    } catch (e, stackTrace) {
      _printDebug('Error adding new chat: $e\n$stackTrace');
    }
  }

  void _updateChatLastMessage(Map<String, dynamic> message) {
    if (!mounted) return;
    
    try {
      final chatId = message['chat_id'] as String;
      final text = message['text'] as String;
      final timestamp = DateTime.parse(message['timestamp'] as String);
      
      _printDebug('Updating last message for chat: $chatId');
      
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
    } catch (e, stackTrace) {
      _printDebug('Error updating last message: $e\n$stackTrace');
    }
  }

  Future<void> _loadInitialData() async {
    if (_authToken == null) {
      _printDebug('No auth token available');
      return;
    }

    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      final response = await _chatService.getInitialData();
      
      if (response.success && mounted) {
        final List<Chat> chats = response.data!;
        _printDebug('Loaded ${chats.length} chats from server');
        
        setState(() {
          final Map<String, Chat> chatMap = {};
          
          for (final chat in _chats) {
            chatMap[chat.id] = chat;
          }
          
          for (final chat in chats) {
            chatMap[chat.id] = chat;
          }
          
          _chats = chatMap.values.toList();
          
          _chats.sort((a, b) {
            final timeA = a.lastMessageTime ?? DateTime(1970);
            final timeB = b.lastMessageTime ?? DateTime(1970);
            return timeB.compareTo(timeA);
          });
        });
      } else if (response.error != null) {
        _printDebug('Error loading chats: ${response.error}');
      }
    } catch (e, stackTrace) {
      _printDebug('Error loading chats: $e\n$stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      _printDebug('Error during logout: $e');
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
    _printDebug('Navigating to chat: ${chat.id}');
    
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
    ).then((_) {
      _loadInitialData();
    });
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

  void _printDebug(String message) {
    debugPrint('[ChatsScreen] $message');
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
            tooltip: 'Контакты',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
            tooltip: 'Обновить',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGroupChat,
        tooltip: 'Создать групповой чат',
        child: const Icon(Icons.add_comment),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'У вас пока нет чатов',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Создайте новый чат или добавьте контакты',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _navigateToCreateGroupChat,
                        child: const Text('Создать чат'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInitialData,
                  child: ListView.builder(
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          lastMessage.isNotEmpty 
                              ? lastMessage 
                              : 'Нет сообщений',
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
                ),
    );
  }

  @override
  void dispose() {
    _printDebug('ChatsScreen disposing');
    
    widget.webSocketService.onNewMessage = null;
    widget.webSocketService.onNewChat = null;
    
    super.dispose();
  }
}