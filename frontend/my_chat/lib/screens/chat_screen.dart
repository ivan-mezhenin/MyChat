import 'package:flutter/material.dart';
import 'package:my_chat/services/chat_service.dart';
import 'package:my_chat/services/websocket_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String userUID;
  final WebSocketService webSocketService;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
    required this.userUID,
    required this.webSocketService,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  Map<String, bool> _userTyping = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupWebSocketListeners();
  }

  void _setupWebSocketListeners() {
    widget.webSocketService.onNewMessage = (message) {
      if (message['chat_id'] == widget.chatId) {
        _addNewMessage(message);
      }
    };

    widget.webSocketService.onUserTyping = (data) {
      if (data['chat_id'] == widget.chatId && data['user_id'] != widget.userUID) {
        setState(() {
          _userTyping[data['user_id']] = data['is_typing'];
        });
      }
    };

    widget.webSocketService.onMessageSent = (data) {
      if (data['chat_id'] == widget.chatId) {
        _handleMessageSent(data['message_id']);
      }
    };
  }

  void _handleMessageSent(String messageId) {
    setState(() {
      for (int i = _messages.length - 1; i >= 0; i--) {
        final message = _messages[i];
        if (message['is_sending'] == true && 
            message['chat_id'] == widget.chatId) {
          _messages[i] = {
            ...message,
            'id': messageId,
            'is_sending': false,
          };
          break;
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getMessages(widget.chatId);
      if (messages['success'] == true) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(messages['messages']);
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  void _addNewMessage(Map<String, dynamic> message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
    
    widget.webSocketService.markMessageAsRead(
      chatId: widget.chatId,
      messageId: message['id'],
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'temp_id': tempId,
      'chat_id': widget.chatId,
      'sender_id': widget.userUID,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
      'is_sending': true,
    };

    setState(() {
      _messages.add(tempMessage);
      _messageController.clear();
    });
    _scrollToBottom();

    _setTypingStatus(false);

    // Отправляем через WebSocket
    widget.webSocketService.sendMessage(
      chatId: widget.chatId,
      text: text,
    );
  }

  void _setTypingStatus(bool isTyping) {
    if (_isTyping != isTyping) {
      _isTyping = isTyping;
      widget.webSocketService.sendTypingStatus(
        chatId: widget.chatId,
        isTyping: isTyping,
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatMessageTime(String timestamp) {
    try {
      final time = DateTime.parse(timestamp);
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['sender_id'] == widget.userUID;
    final isSending = message['is_sending'] == true;
    final isTemp = message['id']?.toString().startsWith('temp_') ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: isMe 
                ? (isSending ? Colors.blue[300] : Colors.blue) 
                : Colors.grey[200],
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message['text'] ?? '',
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMessageTime(message['timestamp'] ?? ''),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    if (isSending) ...[
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isMe ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                    if (isTemp && !isSending) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.check,
                        size: 12,
                        color: isMe ? Colors.white70 : Colors.grey[600],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final typingUsers = _userTyping.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();

    if (typingUsers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Печатает...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatName),
            const SizedBox(height: 2),
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                final typingUsers = _userTyping.entries
                    .where((entry) => entry.value == true)
                    .toList();
                if (typingUsers.isNotEmpty) {
                  return const Text(
                    'Печатает...',
                    style: TextStyle(fontSize: 12),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Начните общение',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Введите сообщение...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                    ),
                    onChanged: (text) {
                      _setTypingStatus(text.isNotEmpty);
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}