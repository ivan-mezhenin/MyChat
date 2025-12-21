import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

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
  final Duration pingInterval;
  final Duration connectTimeout;

  const WebSocketConfig({
    required this.baseUrl,
    this.reconnectDelay = const Duration(seconds: 2),
    this.maxReconnectAttempts = 10,
    this.pingInterval = const Duration(seconds: 25),
    this.connectTimeout = const Duration(seconds: 10),
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
  String? _currentToken;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  int _reconnectAttempts = 0;
  bool _isConnecting = false;
  bool _isDisposed = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _connectionCheckTimer;
  Completer<void>? _connectionCompleter;
  DateTime? _lastMessageTime;
  bool _manualDisconnect = false;

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
    if (_isDisposed) {
      _printDebug('Service disposed, cannot connect');
      return;
    }

    if (_isConnecting) {
      _printDebug('Already connecting, skipping');
      return;
    }

    if (_channel != null && isConnected) {
      _printDebug('Already connected, skipping');
      return;
    }

    _manualDisconnect = false;
    _isConnecting = true;
    _reconnectAttempts = 0;
    _currentToken = token;
    _connectionCompleter = Completer<void>();

    _printDebug('Starting connection attempt...');

    try {
      final url = '${_config.baseUrl}/ws?token=${Uri.encodeComponent(token)}';
      _printDebug('Connecting to $url');
      
      _channel = await _connectWithTimeout(url);
      
      _printDebug('WebSocket channel created, setting up listeners...');
      
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
        cancelOnError: true,
      );

      _startPingTimer();
      
      _startConnectionCheckTimer();

      _isConnecting = false;
      _reconnectAttempts = 0;
      _lastMessageTime = DateTime.now();
      _connectionCompleter?.complete();
      
      _notifyConnectionChanged(true);
      _printDebug('WebSocket connected successfully');
      
    } on TimeoutException catch (e) {
      _isConnecting = false;
      _printDebug('WebSocket connection timeout: ${e.message}');
      _connectionCompleter?.completeError(e);
      _notifyConnectionChanged(false);
      _scheduleReconnect();
    } catch (e, stackTrace) {
      _isConnecting = false;
      _printDebug('Failed to connect WebSocket: $e\n$stackTrace');
      _connectionCompleter?.completeError(e);
      _notifyConnectionChanged(false);
      _scheduleReconnect();
    }
  }

  Future<WebSocketChannel> _connectWithTimeout(String url) async {
    final completer = Completer<WebSocketChannel>();
    
    final timer = Timer(_config.connectTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Connection timeout'));
      }
    });
    
    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(url),
        protocols: ['chat'],
      );
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      timer.cancel();
      completer.complete(channel);
    } catch (e) {
      timer.cancel();
      if (!completer.isCompleted) {
        rethrow;
      }
    }
    
    return completer.future;
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    
    _pingTimer = Timer.periodic(_config.pingInterval, (timer) {
      if (!isConnected || _isDisposed) {
        timer.cancel();
        return;
      }
      
      try {
        final pingMessage = WebSocketMessage(
          type: 'ping',
          data: {'timestamp': DateTime.now().millisecondsSinceEpoch},
        );
        
        _channel?.sink.add(json.encode(pingMessage.toJson()));
        _printDebug('Ping sent');
      } catch (e) {
        _printDebug('Error sending ping: $e');
      }
    });
  }

  void _startConnectionCheckTimer() {
    _connectionCheckTimer?.cancel();
    
    _connectionCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) {
        if (!isConnected || _isDisposed) {
          _printDebug('Connection check failed - not connected');
          timer.cancel();
          return;
        }
        
        if (_lastMessageTime != null) {
          final timeSinceLastMessage = DateTime.now().difference(_lastMessageTime!);
          if (timeSinceLastMessage > const Duration(seconds: 40)) {
            _printDebug('No messages for ${timeSinceLastMessage.inSeconds}s, reconnecting...');
            _handleDisconnection();
            timer.cancel();
          }
        }
      },
    );
  }

  void disconnect() {
    _printDebug('Manual disconnect requested');
    _manualDisconnect = true;
    _performDisconnect();
  }

  void _performDisconnect() {
    _printDebug('Performing disconnect...');
    
    _pingTimer?.cancel();
    _pingTimer = null;
    
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    _subscription?.cancel();
    _subscription = null;
    
    try {
      _channel?.sink.close(status.goingAway);
    } catch (e) {
      _printDebug('Error closing channel: $e');
    }
    _channel = null;
    
    _notifyConnectionChanged(false);
    _printDebug('WebSocket disconnected');
  }

  void _handleDisconnection() {
    _printDebug('WebSocket connection closed');
    
    _pingTimer?.cancel();
    _pingTimer = null;
    
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    
    _subscription?.cancel();
    _subscription = null;
    
    _channel = null;
    
    if (!_manualDisconnect && !_isDisposed) {
      _notifyConnectionChanged(false);
      _scheduleReconnect();
    } else {
      _notifyConnectionChanged(false);
    }
  }

  void _handleError(dynamic error) {
    _printDebug('WebSocket error: $error');
    
    if (error is WebSocketChannelException || 
        error.toString().contains('SocketException') ||
        error.toString().contains('Connection')) {
      _printDebug('Connection error detected, will reconnect');
      _handleDisconnection();
    }
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _isDisposed) {
      _printDebug('Manual disconnect or disposed, skipping reconnect');
      return;
    }

    if (_reconnectAttempts >= _config.maxReconnectAttempts) {
      _printDebug('Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    
    final delaySeconds = _config.reconnectDelay.inSeconds * (_reconnectAttempts + 1);
    final clampedSeconds = delaySeconds.clamp(1, 30);
    final delay = Duration(seconds: clampedSeconds);
    
    _printDebug('Scheduling reconnect in ${delay.inSeconds}s');
    
    _reconnectTimer = Timer(delay, () {
      if (_manualDisconnect || _isDisposed) {
        _printDebug('Canceled reconnect - manual disconnect or disposed');
        return;
      }
      
      _reconnectAttempts++;
      _printDebug('Attempting reconnect ($_reconnectAttempts/${_config.maxReconnectAttempts})');
      
      if (_currentToken != null) {
        connect(_currentToken!);
      } else {
        _printDebug('No token available for reconnect');
      }
    });
  }

  void _notifyConnectionChanged(bool connected) {
    try {
      if (_connectionController.isClosed) {
        _printDebug('Connection controller is closed');
        return;
      }
      
      _connectionController.add(connected);
      onConnectionChanged?.call(connected);
      _printDebug('Connection changed: $connected');
    } catch (e) {
      _printDebug('Error notifying connection change: $e');
    }
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      _lastMessageTime = DateTime.now();
      
      if (rawMessage is! String) {
        _printDebug('Received non-string message: $rawMessage');
        return;
      }

      _printDebug('Received raw message: ${rawMessage.length} chars');
      
      final decoded = json.decode(rawMessage);
      if (decoded is! Map<String, dynamic>) {
        _printDebug('Invalid message format');
        return;
      }

      final messageType = decoded['type']?.toString() ?? 'unknown';
      _printDebug('Processing message type: $messageType');
      
      if (messageType == 'ping' || messageType == 'pong') {
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
    } catch (e, stackTrace) {
      _printDebug('Error handling WebSocket message: $e\n$stackTrace');
    }
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    try {
      _printDebug('New message for chat: ${data['chat_id']}');
      onNewMessage?.call(data);
      _messageController.add(data);
    } catch (e) {
      _printDebug('Error in new message handler: $e');
    }
  }

  void _handleUserTyping(Map<String, dynamic> data) {
    try {
      onUserTyping?.call(data);
      _typingController.add(data);
    } catch (e) {
      _printDebug('Error in typing handler: $e');
    }
  }

  void _handleMessageSent(Map<String, dynamic> data) {
    try {
      _printDebug('Message sent confirmed: ${data['message_id']}');
      onMessageSent?.call(data);
    } catch (e) {
      _printDebug('Error in message sent handler: $e');
    }
  }

  void _handleMessageRead(Map<String, dynamic> data) {
    try {
      onMessageRead?.call(data);
      _readController.add(data);
    } catch (e) {
      _printDebug('Error in message read handler: $e');
    }
  }

  void _handleErrorMessage(Map<String, dynamic> data) {
    _printDebug('WebSocket server error: $data');
  }

  void _handleNewChat(Map<String, dynamic> data) {
    _printDebug('New chat created: ${data['chat_id']}');
    try {
      onNewChat?.call(data);
    } catch (e) {
      _printDebug('Error in new chat handler: $e');
    }
  }

  void sendMessage({
    required String chatId,
    required String text,
  }) {
    if (_channel == null || !isConnected) {
      _printDebug('Cannot send message: not connected, attempting reconnect...');
      
      if (_currentToken != null && !_manualDisconnect && !_isDisposed) {
        _printDebug('Attempting immediate reconnect for message sending');
        _reconnectTimer?.cancel();
        connect(_currentToken!);
      }
      
      return;
    }

    try {
      final message = WebSocketMessage(
        type: 'send_message',
        data: {
          'chat_id': chatId,
          'text': text,
          'temp_id': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      final jsonMessage = json.encode(message.toJson());
      _channel!.sink.add(jsonMessage);
      _printDebug('Message sent to chat $chatId, length: ${jsonMessage.length}');
    } catch (e, stackTrace) {
      _printDebug('Error sending message: $e\n$stackTrace');
      _handleDisconnection();
    }
  }

  void sendTypingStatus({
    required String chatId,
    required bool isTyping,
  }) {
    if (_channel == null || !isConnected) {
      _printDebug('Cannot send typing status: not connected');
      return;
    }

    try {
      final message = WebSocketMessage(
        type: 'typing',
        data: {
          'chat_id': chatId,
          'is_typing': isTyping,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
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
    if (_channel == null || !isConnected) {
      _printDebug('Cannot mark message as read: not connected');
      return;
    }

    try {
      final message = WebSocketMessage(
        type: 'message_read',
        data: {
          'chat_id': chatId,
          'message_id': messageId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );

      _channel!.sink.add(json.encode(message.toJson()));
    } catch (e) {
      _printDebug('Error marking message as read: $e');
    }
  }

  void _printDebug(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    debugPrint('[WebSocket $timestamp] $message');
  }

  bool get isConnected {
    if (_channel == null || _isDisposed) return false;
    
    try {
      return _channel!.closeCode == null;
    } catch (e) {
      return false;
    }
  }

  bool get isConnecting => _isConnecting;
  String? get currentToken => _currentToken;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get readStream => _readController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  Future<void> waitForConnection() async {
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      await _connectionCompleter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('WebSocket connection timeout');
        },
      );
    }
  }

  void dispose() {
  if (_isDisposed) return;
  
  _printDebug('Disposing WebSocketService');
  
  _isDisposed = true;
  _manualDisconnect = true;
  
  _pingTimer?.cancel();
  _pingTimer = null;
  
  _connectionCheckTimer?.cancel();
  _connectionCheckTimer = null;
  
  _reconnectTimer?.cancel();
  _reconnectTimer = null;
  
  try {
    if (_channel != null) {
      _channel!.sink.close(status.goingAway);
    }
  } catch (e) {
    _printDebug('Error closing channel: $e');
  }
  
  _subscription?.cancel();
  _subscription = null;
  _channel = null;
  
  try {
    if (!_messageController.isClosed) _messageController.close();
  } catch (e) {
    _printDebug('Error closing message controller: $e');
  }
  
  try {
    if (!_typingController.isClosed) _typingController.close();
  } catch (e) {
    _printDebug('Error closing typing controller: $e');
  }
  
  try {
    if (!_readController.isClosed) _readController.close();
  } catch (e) {
    _printDebug('Error closing read controller: $e');
  }
  
  try {
    if (!_connectionController.isClosed) _connectionController.close();
  } catch (e) {
    _printDebug('Error closing connection controller: $e');
  }
  
  if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
    _connectionCompleter!.complete();
  }
  _connectionCompleter = null;
  
  _currentToken = null;
}
}