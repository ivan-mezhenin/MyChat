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
  Timer? _typingDebounceTimer;
  final Set<String> _readMessages = <String>{};
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _printDebug('ChatScreen init for chat: ${widget.chatId}');
    _setupWebSocketListeners();
    _initializeServicesAndLoadMessages();
  }

  Future<void> _initializeServicesAndLoadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _chatService = ChatService(prefs: prefs);
      await _loadMessages();
    } catch (e, stackTrace) {
      _printDebug('Error initializing: $e\n$stackTrace');
    }
  }

  void _setupWebSocketListeners() {
    _printDebug('Setting up WebSocket listeners');
    
    widget.webSocketService.onNewMessage = null;
    widget.webSocketService.onUserTyping = null;
    widget.webSocketService.onMessageSent = null;
    widget.webSocketService.onMessageRead = null;
    
    widget.webSocketService.onNewMessage = (message) {
      if (message['chat_id'] == widget.chatId) {
        _printDebug('New message for this chat');
        final newMessage = Message.fromJson(message);
        _addNewMessage(newMessage);
      }
    };

    widget.webSocketService.onUserTyping = (data) {
      if (data['chat_id'] == widget.chatId && data['user_id'] != widget.userUID) {
        _printDebug('User typing: ${data['user_id']} = ${data['is_typing']}');
        setState(() {
          _userTyping[data['user_id']] = data['is_typing'];
        });
      }
    };

    widget.webSocketService.onMessageSent = (data) {
      if (data['chat_id'] == widget.chatId) {
        _printDebug('Message sent confirmed: ${data['message_id']}');
        _handleMessageSent(data['message_id']);
      }
    };

    widget.webSocketService.onMessageRead = (data) {
      if (data['chat_id'] == widget.chatId) {
        _printDebug('Message read: ${data['message_id']}');
      }
    };
  }

  void _handleMessageSent(String messageId) {
    if (!mounted) return;
    
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
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      final result = await _chatService.getMessages(widget.chatId);
      
      if (result.success && mounted) {
        final List<Message> messages = result.data!;
        _printDebug('Loaded ${messages.length} messages');
        
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
        _markVisibleMessagesAsRead();
      } else if (result.error != null) {
        _printDebug('Error loading messages: ${result.error}');
      }
    } catch (e, stackTrace) {
      _printDebug('Error while loading messages: $e\n$stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addNewMessage(Message message) {
    if (!mounted) return;
    
    _printDebug('Adding new message from ${message.senderId}');
    
    setState(() {
      final existingIndex = _messages.indexWhere((m) => m.id == message.id);
      
      if (existingIndex >= 0) {
        _messages[existingIndex] = message;
      } else {
        _messages.add(message);
      }
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
          !_readMessages.contains(message.id) &&
          !message.isSending) {
        _readMessages.add(message.id);
        
        widget.webSocketService.markMessageAsRead(
          chatId: widget.chatId,
          messageId: message.id,
        );
        
        _printDebug('Marked message as read: ${message.id}');
      }
    }
  }

void _sendMessage() {
  if (_isSending) return;
  
  final text = _messageController.text.trim();
  if (text.isEmpty) return;

  setState(() => _isSending = true);
  
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

  try {
    widget.webSocketService.sendMessage(
      chatId: widget.chatId,
      text: text,
    );
    _printDebug('Message sent via WebSocket');
    
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.tempId == tempMessage.tempId);
          if (index != -1 && _messages[index].isSending) {
            _printDebug('Message not confirmed, marking as failed');
            _messages[index] = Message(
              id: _messages[index].id,
              chatId: _messages[index].chatId,
              senderId: _messages[index].senderId,
              text: _messages[index].text,
              timestamp: _messages[index].timestamp,
              isSending: false,
              tempId: null,
            );
          }
        });
      }
    });
  } catch (e, stackTrace) {
    _printDebug('Error sending message: $e\n$stackTrace');
    _showErrorSnackBar('Не удалось отправить сообщение. Проверьте соединение.');
  } finally {
    setState(() => _isSending = false);
  }
}

  void _setTypingStatus(bool isTyping) {
    if (_isTyping != isTyping) {
      _isTyping = isTyping;
      
      _typingDebounceTimer?.cancel();
      
      _typingDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (widget.webSocketService.isConnected) {
          widget.webSocketService.sendTypingStatus(
            chatId: widget.chatId,
            isTyping: isTyping,
          );
          _printDebug('Typing status: $isTyping');
        }
      });
    }
  }

  void _onTextChanged(String text) {
    final isTyping = text.isNotEmpty;
    
    _typingTimer?.cancel();
    
    if (isTyping && !_isTyping) {
      _setTypingStatus(true);
    }
    
    if (!isTyping && _isTyping) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (_messageController.text.isEmpty && _isTyping && mounted) {
          _setTypingStatus(false);
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    if (isMe && isSending)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1,
                            color: Colors.white70,
                          ),
                        ),
                      ),
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
                width: 16,
                height: 16,
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

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _printDebug(String message) {
    debugPrint('[ChatScreen ${widget.chatId}] $message');
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
            Text(
              widget.chatName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
          if (_isLoading)
            const LinearProgressIndicator(),
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? const Center(
                    child: Text(
                      'Начните общение',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadMessages,
                    child: ListView.builder(
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
                        vertical: 12.0,
                      ),
                    ),
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isSending,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
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
    _printDebug('ChatScreen disposing');
    
    _typingTimer?.cancel();
    _typingDebounceTimer?.cancel();
    
    if (_isTyping) {
      widget.webSocketService.sendTypingStatus(
        chatId: widget.chatId,
        isTyping: false,
      );
    }
    
    widget.webSocketService.onNewMessage = null;
    widget.webSocketService.onUserTyping = null;
    widget.webSocketService.onMessageSent = null;
    widget.webSocketService.onMessageRead = null;
    
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}