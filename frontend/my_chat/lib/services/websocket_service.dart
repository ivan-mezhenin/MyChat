// lib/services/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketService {
  static WebSocketService? _instance;
  WebSocketChannel? _channel;
  String? _token;
  String? _userId;
  
  // Callbacks для обработки событий
  Function(Map<String, dynamic>)? onNewMessage;
  Function(Map<String, dynamic>)? onUserTyping;
  Function(Map<String, dynamic>)? onMessageRead;
  
  // Поток для прослушивания сообщений
  Stream<Map<String, dynamic>>? get stream => 
      _channel?.stream.map((data) => json.decode(data) as Map<String, dynamic>);

  WebSocketService._internal();

  factory WebSocketService() {
    _instance ??= WebSocketService._internal();
    return _instance!;
  }

  // Подключение к WebSocket серверу
  Future<void> connect(String token, String userId, {String baseUrl = 'ws://localhost:8080'}) async {
    if (_channel != null && _channel!.closeCode == null) {
      await disconnect();
    }

    _token = token;
    _userId = userId;
    
    final wsUrl = Uri.parse('$baseUrl/ws?token=$token');
    
    try {
      _channel = IOWebSocketChannel.connect(wsUrl);
      
      // Начинаем слушать сообщения
      _listenToMessages();
      
      print('WebSocket connected successfully');
    } catch (e) {
      print('WebSocket connection error: $e');
      throw Exception('Failed to connect to WebSocket: $e');
    }
  }

  // Отключение от сервера
  Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
      print('WebSocket disconnected');
    }
  }

  // Прослушивание входящих сообщений
  void _listenToMessages() {
    _channel?.stream.listen(
      (dynamic message) {
        try {
          final data = json.decode(message) as Map<String, dynamic>;
          _handleIncomingEvent(data);
        } catch (e) {
          print('Error parsing WebSocket message: $e');
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        print('WebSocket connection closed');
        _channel = null;
      },
    );
  }

  // Обработка входящих событий
  void _handleIncomingEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    
    switch (type) {
      case 'new_message':
        onNewMessage?.call(event);
        break;
        
      case 'user_typing':
        onUserTyping?.call(event);
        break;
        
      case 'message_sent':
        // Подтверждение отправки сообщения
        print('Message sent confirmation: $event');
        break;
        
      case 'error':
        print('WebSocket error: ${event['data']}');
        break;
        
      default:
        print('Unknown WebSocket event: $event');
    }
  }

  // Отправка сообщения через WebSocket
  void sendMessage(String chatId, String text) {
    if (_channel == null || _channel!.closeCode != null) {
      throw Exception('WebSocket is not connected');
    }

    final message = {
      'type': 'send_message',
      'chat_id': chatId,
      'user_id': _userId,
      'data': {
        'chat_id': chatId,
        'text': text,
      },
    };

    _channel!.sink.add(json.encode(message));
  }

  // Отправка события "печатает"
  void sendTypingEvent(String chatId, bool isTyping) {
    if (_channel == null || _channel!.closeCode != null) return;

    final event = {
      'type': 'typing',
      'chat_id': chatId,
      'user_id': _userId,
      'data': {
        'chat_id': chatId,
        'is_typing': isTyping,
      },
    };

    _channel!.sink.add(json.encode(event));
  }

  // Отметить сообщение как прочитанное
  void markMessageAsRead(String chatId, String messageId) {
    if (_channel == null || _channel!.closeCode != null) return;

    final event = {
      'type': 'message_read',
      'chat_id': chatId,
      'user_id': _userId,
      'data': {
        'chat_id': chatId,
        'message_id': messageId,
      },
    };

    _channel!.sink.add(json.encode(event));
  }

  // Проверка подключения
  bool get isConnected => _channel != null && _channel!.closeCode == null;

  // Переподключение при необходимости
  Future<void> reconnect() async {
    if (_token != null && _userId != null && !isConnected) {
      await connect(_token!, _userId!);
    }
  }
}