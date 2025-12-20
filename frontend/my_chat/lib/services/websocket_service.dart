import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketMessageCallback = void Function(Map<String, dynamic> data);
typedef WebSocketConnectionCallback = void Function(bool connected);

class WebSocketMessage {
  final String type;
  final Map<String, dynamic> data;

  WebSocketMessage({
    required this.type,
    required this.data,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) =>
      WebSocketMessage(
        type: json['type'] as String,
        data: Map<String, dynamic>.from(json['data'] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'data': data,
      };
}

class WebSocketConfig {
  final String baseUrl;
  final Duration reconnectDelay;
  final int maxReconnectAttempts;
  final Duration connectionTimeout;

  const WebSocketConfig({
    required this.baseUrl,
    this.reconnectDelay = const Duration(seconds: 3),
    this.maxReconnectAttempts = 5,
    this.connectionTimeout = const Duration(seconds: 1000),
  });

  factory WebSocketConfig.development() => WebSocketConfig(
        baseUrl: 'ws://192.168.1.104:8080',
      );

  factory WebSocketConfig.production() => WebSocketConfig(
        baseUrl: 'wss://api.yourdomain.com',
      );
}

class WebSocketService {
  final WebSocketConfig _config;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  int _reconnectAttempts = 0;
  bool _isConnecting = false;
  Timer? _reconnectTimer;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _readController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  WebSocketMessageCallback? onNewMessage;
  WebSocketMessageCallback? onUserTyping;
  WebSocketMessageCallback? onMessageSent;
  WebSocketMessageCallback? onMessageRead;
  WebSocketMessageCallback? onNewChat;
  WebSocketConnectionCallback? onConnectionChanged;

  WebSocketService({
    WebSocketConfig? config,
  }) : _config = config ?? WebSocketConfig.development();

  Future<void> connect(String token) async {
    if (_isConnecting || _channel != null) {
      return;
    }

    _isConnecting = true;
    _reconnectAttempts = 0;

    try {
      final url = '${_config.baseUrl}/ws?token=${Uri.encodeComponent(token)}';
      
      _channel = WebSocketChannel.connect(
        Uri.parse(url),
      );

      _subscription = _channel!.stream
          .timeout(_config.connectionTimeout)
          .listen(
            _handleMessage,
            onError: _handleError,
            onDone: _handleDisconnection,
            cancelOnError: true,
          );

      _isConnecting = false;
      _reconnectAttempts = 0;
      
      _notifyConnectionChanged(true);
      _printDebug('WebSocket connected successfully');
    } catch (e) {
      _isConnecting = false;
      _printDebug('Failed to connect WebSocket: $e');
      _scheduleReconnect(token);
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    _subscription?.cancel();
    _subscription = null;
    
    _channel?.sink.close();
    _channel = null;
    
    _reconnectAttempts = 0;
    _isConnecting = false;
    
    _notifyConnectionChanged(false);
    _printDebug('WebSocket disconnected');
  }

  void _handleDisconnection() {
    _printDebug('WebSocket connection closed');
    _channel = null;
    _subscription = null;
    _notifyConnectionChanged(false);
  }

  void _handleError(error) {
    _printDebug('WebSocket error: $error');
    _channel = null;
    _subscription = null;
    _notifyConnectionChanged(false);
  }

  void _scheduleReconnect(String token) {
    if (_reconnectAttempts >= _config.maxReconnectAttempts) {
      _printDebug('Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    
    final delay = Duration(
      seconds: _config.reconnectDelay.inSeconds * (_reconnectAttempts + 1),
    );
    
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      _printDebug('Attempting reconnect ($_reconnectAttempts/${_config.maxReconnectAttempts})');
      connect(token);
    });
  }

  void _notifyConnectionChanged(bool connected) {
    _connectionController.add(connected);
    onConnectionChanged?.call(connected);
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      if (rawMessage is! String) {
        _printDebug('Received non-string message: $rawMessage');
        return;
      }

      final decoded = json.decode(rawMessage);
      if (decoded is! Map<String, dynamic>) {
        _printDebug('Invalid message format: $decoded');
        return;
      }

      final message = WebSocketMessage.fromJson(decoded);
      
      switch (message.type) {
        case 'new_message':
          _handleNewMessage(message.data);
          break;
        case 'user_typing':
          _handleUserTyping(message.data);
          break;
        case 'message_sent':
          _handleMessageSent(message.data);
          break;
        case 'message_read':
          _handleMessageRead(message.data);
          break;
        case 'error':
          _handleErrorMessage(message.data);
          break;
        case 'chat_created':
          _handleNewChat(message.data);
          break;
        default:
          _printDebug('Unknown message type: ${message.type}');
      }
    } catch (e) {
      _printDebug('Error handling WebSocket message: $e');
    }
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    onNewMessage?.call(data);
    _messageController.add(data);
  }

  void _handleUserTyping(Map<String, dynamic> data) {
    onUserTyping?.call(data);
    _typingController.add(data);
  }

  void _handleMessageSent(Map<String, dynamic> data) {
    onMessageSent?.call(data);
  }

  void _handleMessageRead(Map<String, dynamic> data) {
    onMessageRead?.call(data);
    _readController.add(data);
  }

  void _handleErrorMessage(Map<String, dynamic> data) {
    _printDebug('WebSocket server error: $data');
  }

  void sendMessage({
    required String chatId,
    required String text,
  }) {
    if (_channel == null) {
      _printDebug('Cannot send message: not connected');
      return;
    }

    try {
      final message = WebSocketMessage(
        type: 'send_message',
        data: {
          'chat_id': chatId,
          'text': text,
        },
      );

      _channel!.sink.add(json.encode(message.toJson()));
    } catch (e) {
      _printDebug('Error sending message: $e');
    }
  }

  void sendTypingStatus({
    required String chatId,
    required bool isTyping,
  }) {
    if (_channel == null) return;

    try {
      final message = WebSocketMessage(
        type: 'typing',
        data: {
          'chat_id': chatId,
          'is_typing': isTyping,
        },
      );

      _channel!.sink.add(json.encode(message.toJson()));
    } catch (e) {
      _printDebug('Error sending typing status: $e');
    }
  }

  void markMessageAsRead({
    required String chatId,
    required String messageId,
  }) {
    if (_channel == null) return;

    try {
      final message = WebSocketMessage(
        type: 'message_read',
        data: {
          'chat_id': chatId,
          'message_id': messageId,
        },
      );

      _channel!.sink.add(json.encode(message.toJson()));
    } catch (e) {
      _printDebug('Error marking message as read: $e');
    }
  }

  void _printDebug(String message) {
    debugPrint('[WebSocket] $message');
  }

   void _handleNewChat(Map<String, dynamic> data) {
    onNewChat?.call(data);
  }

  bool get isConnected => _channel != null;
  bool get isConnecting => _isConnecting;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get readStream => _readController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  void dispose() {
    disconnect();
    
    _messageController.close();
    _typingController.close();
    _readController.close();
    _connectionController.close();
    
    _reconnectTimer?.cancel();
  }
}