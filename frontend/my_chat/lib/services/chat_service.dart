import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  static const String _baseUrl = 'http://localhost:8080';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>> getInitialData(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/initial-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          ...json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load data: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getMessages(String chatId) async {
    final token = await _getToken();
    if (token == null) {
      return {
        'success': false,
        'error': 'Not authenticated',
      };
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/chats/$chatId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'messages': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load messages: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}