import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  Function(Map<String, dynamic> data)? onMessageSent;
  static const String _baseUrl = 'ws://localhost:8080';
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>> _messageController =
StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _readController =
      StreamController<Map<String, dynamic>>.broadcast();

  Function(Map<String, dynamic> message)? onNewMessage;
  Function(Map<String, dynamic> data)? onUserTyping;
  Function(Map<String, dynamic> data)? onMessageRead;

  Future<void> connect(String token) async {
    try {
      final url = '$_baseUrl/ws?token=$token';
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _reconnect(token);
        },
        onDone: () {
          print('WebSocket disconnected');
          _reconnect(token);
        },
      );

      print('WebSocket connected');
    } catch (e) {
      print('Failed to connect WebSocket: $e');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message);
      final type = data['type'];

      switch (type) {
        case 'new_message':
          onNewMessage?.call(Map<String, dynamic>.from(data['data']));
          _messageController.add(Map<String, dynamic>.from(data['data']));
          break;
        case 'user_typing':
          onUserTyping?.call(Map<String, dynamic>.from(data['data']));
          _typingController.add(Map<String, dynamic>.from(data['data']));
          break;
      case 'message_sent':
        print('Message sent: ${data['data']}');
        onMessageSent?.call(Map<String, dynamic>.from(data['data']));
        break;
        case 'error':
          print('WebSocket error: ${data['data']}');
          break;
        default:
          print('Unknown message type: $type');
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  void sendMessage({
    required String chatId,
    required String text,
  }) {
    if (_channel == null) return;

    final message = {
      'type': 'send_message',
      'data': {
        'chat_id': chatId,
        'text': text,
      },
    };

    _channel!.sink.add(json.encode(message));
  }

  void sendTypingStatus({
    required String chatId,
    required bool isTyping,
  }) {
    if (_channel == null) return;

    final message = {
      'type': 'typing',
      'data': {
        'chat_id': chatId,
        'is_typing': isTyping,
      },
    };

    _channel!.sink.add(json.encode(message));
  }

  void markMessageAsRead({
    required String chatId,
    required String messageId,
  }) {
    if (_channel == null) return;

    final message = {
      'type': 'message_read',
      'data': {
        'chat_id': chatId,
        'message_id': messageId,
      },
    };

    _channel!.sink.add(json.encode(message));
  }

  void _reconnect(String token) async {
    await Future.delayed(const Duration(seconds: 3));
    connect(token);
  }

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get readStream => _readController.stream;

  void disconnect() {
    _channel?.sink.close();
    _messageController.close();
    _typingController.close();
    _readController.close();
  }

  bool isConnected() {
    return _channel != null;
  }
}