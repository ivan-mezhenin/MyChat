import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_chat/models/contact.dart';
import 'chat_service.dart';

class ContactService {
  final ChatServiceConfig _config;
  final SharedPreferences _prefs;
  final http.Client _client;

  ContactService({
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

  Future<http.Response> _makeAuthenticatedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _getAuthToken();
    final uri = Uri.parse('${_config.baseUrl}$path');
    
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    switch (method) {
      case 'GET':
        return await _client.get(uri, headers: headers);
      case 'POST':
        return await _client.post(
          uri,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
      case 'DELETE':
        return await _client.delete(uri, headers: headers);
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }

Future<ApiResponse<List<Contact>>> getContacts() async {
  try {
    debugPrint('ContactService: getting contacts...');
    final response = await _makeAuthenticatedRequest('GET', '/api/contacts');
    
    debugPrint('ContactService response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      try {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final contactsJson = jsonData['contacts'] as List<dynamic>;
        
        final contacts = contactsJson
            .map((c) => Contact.fromJson(c as Map<String, dynamic>))
            .toList();
        
        debugPrint('ContactService: loaded ${contacts.length} contacts');
        return ApiResponse.success(contacts, response.statusCode);
      } catch (e) {
        debugPrint('ContactService JSON parsing error: $e');
        return ApiResponse.error('Ошибка обработки данных: $e', response.statusCode);
      }
    } else {
      debugPrint('ContactService error status: ${response.statusCode}');
      return ApiResponse.error('Не удалось загрузить контакты (${response.statusCode})', response.statusCode);
    }
  } catch (e, stackTrace) {
    debugPrint('ContactService exception: $e');
    debugPrint('Stack trace: $stackTrace');
    return ApiResponse.error('Сетевая ошибка: $e');
  }
}

  Future<ApiResponse<Contact>> addContact(String email, {String? notes}) async {
    try {
      final response = await _makeAuthenticatedRequest(
        'POST',
        '/api/contacts',
        body: {
          'email': email,
          if (notes != null) 'notes': notes,
        },
      );
      
      if (response.statusCode == 201) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final contact = Contact.fromJson(jsonData['contact'] as Map<String, dynamic>);
        return ApiResponse.success(contact, response.statusCode);
      } else {
        final error = json.decode(response.body)['error'] as String? ?? 'Unknown error';
        return ApiResponse.error(error, response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error('Error: $e');
    }
  }

  Future<ApiResponse<void>> deleteContact(String contactId) async {
    try {
      final response = await _makeAuthenticatedRequest(
        'DELETE',
        '/api/contacts/$contactId',
      );
      
      if (response.statusCode == 200) {
        return ApiResponse.success(null, response.statusCode);
      } else {
        return ApiResponse.error('Failed to delete contact', response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error('Error: $e');
    }
  }

  Future<ApiResponse<List<UserSearchResult>>> searchUsers(String query) async {
    try {
      final uri = Uri.parse('${_config.baseUrl}/api/contacts/search')
          .replace(queryParameters: {'q': query});
      
      final token = await _getAuthToken();
      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final usersJson = jsonData['users'] as List<dynamic>;
        
        final users = usersJson
            .map((u) => UserSearchResult.fromJson(u as Map<String, dynamic>))
            .toList();
        
        return ApiResponse.success(users, response.statusCode);
      } else {
        return ApiResponse.error('Search failed', response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error('Error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}

class UserSearchResult {
  final String uid;
  final String email;
  final String name;
  final bool isContact;

  UserSearchResult({
    required this.uid,
    required this.email,
    required this.name,
    required this.isContact,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) => UserSearchResult(
    uid: json['uid'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    isContact: json['is_contact'] ?? false,
  );

  String get displayName => name.isNotEmpty ? name : email;
}