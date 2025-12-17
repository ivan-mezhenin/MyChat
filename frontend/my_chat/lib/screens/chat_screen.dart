import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_chat/services/chat_service.dart';
import 'package:my_chat/services/websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String userUID;
  final WebSocketService webSocketService;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.userUID,
    required this.webSocketService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatService _chatService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Message> _messages = [];
  bool _isTyping = false;
  final Map<String, bool> _userTyping = {};
  Timer? _typingTimer;
  final Set<String> _readMessages = <String>{};

 @override
  void initState() {
    super.initState();
    _setupWebSocketListeners();
    _initializeServicesAndLoadMessages();
  }

  Future<void> _initializeServicesAndLoadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    _chatService = ChatService(prefs: prefs);
    await _loadMessages();
  }

  void _setupWebSocketListeners() {
    widget.webSocketService.onNewMessage = (message) {
      if (message['chat_id'] == widget.chatId) {
        final newMessage = Message.fromJson(message);
        _addNewMessage(newMessage);
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
        if (message.isSending && message.tempId != null) {
          _messages[i] = Message(
            id: messageId,
            chatId: message.chatId,
            senderId: message.senderId,
            text: message.text,
            timestamp: message.timestamp,
            isSending: false,
            tempId: null,
          );
          break;
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final result = await _chatService.getMessages(widget.chatId);
      if (result.success) {
        final List<Message> messages = result.data!;
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
        _markVisibleMessagesAsRead();
      }
    }
    catch(e) {
        debugPrint('Error while loading messages: $e');
    }
  }

  void _addNewMessage(Message message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
    _markVisibleMessagesAsRead();
  }

  void _markVisibleMessagesAsRead() {
    const messagesToMark = 5;
    final startIndex = _messages.length > messagesToMark 
        ? _messages.length - messagesToMark 
        : 0;
    
    for (int i = startIndex; i < _messages.length; i++) {
      final message = _messages[i];
      if (message.senderId != widget.userUID && 
          !_readMessages.contains(message.id)) {
        _readMessages.add(message.id);
        widget.webSocketService.markMessageAsRead(
          chatId: widget.chatId,
          messageId: message.id,
        );
      }
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final tempMessage = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      chatId: widget.chatId,
      senderId: widget.userUID,
      text: text,
      timestamp: DateTime.now(),
      isSending: true,
      tempId: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    setState(() {
      _messages.add(tempMessage);
      _messageController.clear();
    });
    _scrollToBottom();

    _setTypingStatus(false);

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

  void _onTextChanged(String text) {
    final isTyping = text.isNotEmpty;
    
    _typingTimer?.cancel();
    
    if (isTyping && !_isTyping) {
      _setTypingStatus(true);
    }
    
    if (!isTyping && _isTyping) {
      _typingTimer = Timer(const Duration(seconds: 1), () {
        if (_messageController.text.isEmpty && _isTyping) {
          _setTypingStatus(false);
        }
      });
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

  Widget _buildMessageBubble(Message message) {
    final isMe = message.senderId == widget.userUID;
    final isSending = message.isSending;

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
                  message.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
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
          child: Text(
            'Печатает...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typingUsers = _userTyping.entries
        .where((entry) => entry.value == true)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatName),
            if (typingUsers.isNotEmpty) ...[
              const SizedBox(height: 2),
              const Text(
                'Печатает...',
                style: TextStyle(fontSize: 12),
              ),
            ],
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
                    onChanged: _onTextChanged,
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
    _typingTimer?.cancel();
    
    widget.webSocketService.onNewMessage = null;
    widget.webSocketService.onUserTyping = null;
    widget.webSocketService.onMessageSent = null;
    
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}