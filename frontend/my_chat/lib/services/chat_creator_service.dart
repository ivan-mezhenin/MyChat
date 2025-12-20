import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_service.dart';
import 'package:my_chat/models/contact.dart';

class ChatCreationResponse {
  final String id;
  final String name;
  final String type;
  final String createdBy;
  final DateTime createdAt;
  final List<String> participants;

  ChatCreationResponse({
    required this.id,
    required this.name,
    required this.type,
    required this.createdBy,
    required this.createdAt,
    required this.participants,
  });

  factory ChatCreationResponse.fromJson(Map<String, dynamic> json) => ChatCreationResponse(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    createdBy: json['created_by'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    participants: List<String>.from(json['participants'] as List),
  );
}

class ChatCreationService {
  final ChatServiceConfig _config;
  final SharedPreferences _prefs;
  final http.Client _client;

  ChatCreationService({
    required SharedPreferences prefs,
    http.Client? client,
    ChatServiceConfig? config,
  })  : _prefs = prefs,
        _client = client ?? http.Client(),
        _config = config ?? ChatServiceConfig.development();

  Future<String> _getAuthToken() async {
    final token = _prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return token;
  }

  Future<ApiResponse<ChatCreationResponse>> createChatFromContacts({
    required String chatName,
    required List<String> contactIds,
    required String chatType,
  }) async {
    try {
      final token = await _getAuthToken();
      final uri = Uri.parse('${_config.baseUrl}/api/chats/create-from-contacts');
      
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'chat_name': chatName,
          'contact_ids': contactIds,
          'chat_type': chatType,
        }),
      );

      if (response.statusCode == 201) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final chat = ChatCreationResponse.fromJson(jsonData['chat'] as Map<String, dynamic>);
        return ApiResponse.success(chat, response.statusCode);
      } else {
        final error = json.decode(response.body)['error'] as String? ?? 'Failed to create chat';
        return ApiResponse.error(error, response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error('Error: $e');
    }
  }

  Future<ApiResponse<ChatCreationResponse>> createPrivateChat(String contactId) async {
    try {
      final token = await _getAuthToken();
      final uri = Uri.parse('${_config.baseUrl}/api/chats/create-private/$contactId');
      
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 201) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final chat = ChatCreationResponse.fromJson(jsonData['chat'] as Map<String, dynamic>);
        return ApiResponse.success(chat, response.statusCode);
      } else {
        final error = json.decode(response.body)['error'] as String? ?? 'Failed to create private chat';
        return ApiResponse.error(error, response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error('Error: $e');
    }
  }

  Future<ApiResponse<List<Contact>>> getContactsFromChatHandler() async {
    try {
      final token = await _getAuthToken();
      final uri = Uri.parse('${_config.baseUrl}/api/chats/contacts');
      
      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final contactsJson = jsonData['contacts'] as List<dynamic>;
        
        final contacts = contactsJson
            .map((c) => Contact.fromJson(c as Map<String, dynamic>))
            .toList();
        
        return ApiResponse.success(contacts, response.statusCode);
      } else {
        return ApiResponse.error('Failed to load contacts', response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error('Error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}