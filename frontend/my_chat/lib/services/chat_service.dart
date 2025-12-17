import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  factory ApiResponse.success(T data, [int? statusCode]) => ApiResponse(
        success: true,
        data: data,
        statusCode: statusCode,
      );

  factory ApiResponse.error(String error, [int? statusCode]) => ApiResponse(
        success: false,
        error: error,
        statusCode: statusCode,
      );
}

class Chat {
  final String id;
  final String name;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final List<String> participantIds;

  Chat({
    required this.id,
    required this.name,
    this.lastMessage,
    this.lastMessageTime,
    required this.participantIds,
  });

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
        id: json['id'] as String,
        name: json['name'] as String,
        lastMessage: json['last_message'] as String?,
        lastMessageTime: json['last_message_time'] != null
            ? DateTime.parse(json['last_message_time'] as String)
            : null,
        participantIds: List<String>.from(json['participant_ids'] ?? []),
      );
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isSending;
  final String? tempId;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isSending = false,
    this.tempId,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        chatId: json['chat_id'] as String,
        senderId: json['sender_id'] as String,
        text: json['text'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isSending: json['is_sending'] ?? false,
        tempId: json['temp_id'] as String?,
      );
}

class ChatServiceConfig {
  final String baseUrl;
  final Duration requestTimeout;
  final int maxRetries;

  const ChatServiceConfig({
    required this.baseUrl,
    this.requestTimeout = const Duration(seconds: 10),
    this.maxRetries = 3,
  });

  factory ChatServiceConfig.development() => ChatServiceConfig(
        baseUrl: 'http://192.168.1.104:8080',
      );

  factory ChatServiceConfig.production() => ChatServiceConfig(
        baseUrl: 'https://api.yourdomain.com',
      );
}

class ChatServiceException implements Exception {
  final String message;
  final int? statusCode;

  ChatServiceException(this.message, [this.statusCode]);

  @override
  String toString() => 'ChatServiceException: $message${statusCode != null ? ' ($statusCode)' : ''}';
}

class AuthenticationException extends ChatServiceException {
  AuthenticationException([String? message]) 
    : super(message ?? 'Authentication required');
}

class NetworkException extends ChatServiceException {
  NetworkException([String? message]) 
    : super(message ?? 'Network error occurred');
}

class ChatService {
  final ChatServiceConfig _config;
  final SharedPreferences _prefs;
  final http.Client _client;

  ChatService({
    required SharedPreferences prefs,
    http.Client? client,
    ChatServiceConfig? config,
  })  : _prefs = prefs,
        _client = client ?? http.Client(),
        _config = config ?? ChatServiceConfig.development();

  Future<String> _getAuthToken() async {
    final token = _prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw AuthenticationException('No authentication token found');
    }
    return token;
  }

  Future<http.Response> _makeRequestWithRetry(
    Future<http.Response> Function() request, {
    int retryCount = 0,
  }) async {
    try {
      return await request().timeout(_config.requestTimeout);
    } on http.ClientException catch (e) {
      if (retryCount < _config.maxRetries) {
        await Future.delayed(Duration(seconds: 1 << retryCount));
        return _makeRequestWithRetry(request, retryCount: retryCount + 1);
      }
      throw NetworkException(e.message);
    } on TimeoutException {
      if (retryCount < _config.maxRetries) {
        await Future.delayed(Duration(seconds: 1 << retryCount));
        return _makeRequestWithRetry(request, retryCount: retryCount + 1);
      }
      throw NetworkException('Request timeout');
    }
  }

  Future<http.Response> _authenticatedGet(String path) async {
    final token = await _getAuthToken();
    final uri = Uri.parse('${_config.baseUrl}$path');
    
    return _makeRequestWithRetry(() async {
      return await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
    });
  }

  Map<String, dynamic> _parseJsonResponse(http.Response response) {
    if (response.body.isEmpty) {
      throw ChatServiceException('Empty response body', response.statusCode);
    }

    try {
      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      return jsonData;
    } on FormatException {
      throw ChatServiceException('Invalid JSON response', response.statusCode);
    }
  }

  void _validateResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthenticationException('Invalid or expired token');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatServiceException(
        'Server error: ${response.statusCode}',
        response.statusCode,
      );
    }
  }

  Future<ApiResponse<List<Chat>>> getInitialData() async {
    try {
      final response = await _authenticatedGet('/api/auth/initial-data');
      _validateResponse(response);
      
      final jsonData = _parseJsonResponse(response);
      final chatsJson = jsonData['chats'] as List<dynamic>;
      
      final chats = chatsJson
          .map((chatJson) => Chat.fromJson(chatJson as Map<String, dynamic>))
          .toList();
      
      return ApiResponse.success(chats, response.statusCode);
    } on AuthenticationException catch (e) {
      return ApiResponse.error(e.message, 401);
    } on ChatServiceException catch (e) {
      return ApiResponse.error(e.message, e.statusCode);
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<List<Message>>> getMessages(String chatId) async {
    try {
      if (chatId.isEmpty) {
        throw ChatServiceException('Chat ID cannot be empty');
      }

      final response = await _authenticatedGet('/api/chats/$chatId/messages');
      _validateResponse(response);
      
      final jsonData = _parseJsonResponse(response);
      final messagesJson = jsonData['messages'] as List<dynamic>;
      
      final messages = messagesJson
          .map((messageJson) => Message.fromJson(messageJson as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      return ApiResponse.success(messages, response.statusCode);
    } on AuthenticationException catch (e) {
      return ApiResponse.error(e.message, 401);
    } on ChatServiceException catch (e) {
      return ApiResponse.error(e.message, e.statusCode);
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}