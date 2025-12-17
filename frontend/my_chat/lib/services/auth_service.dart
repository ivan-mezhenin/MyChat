import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'chat_service.dart';

class ApiConfig {
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
  };

  factory ApiConfig.development() => ApiConfig(
        baseUrl: 'http://192.168.1.104:8080',
      );

  factory ApiConfig.production() => ApiConfig(
        baseUrl: 'https://api.yourdomain.com',
      );

  const ApiConfig({
    required this.baseUrl,
    this.requestTimeout = const Duration(seconds: 10),
  });

  final String baseUrl;
  final Duration requestTimeout;
}

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

class UserData {
  final String uid;
  final String name;
  final String email;

  UserData({
    required this.uid,
    required this.name,
    required this.email,
  });

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
        uid: json['uid'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
      };
}

class LoginResponse {
  final String token;
  final UserData user;
  final List<Chat> chats;

  LoginResponse({
    required this.token,
    required this.user,
    required this.chats,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        token: json['token'] as String,
        user: UserData.fromJson(json['user'] as Map<String, dynamic>),
        chats: (json['chats'] as List<dynamic>)
            .map((chatJson) => Chat.fromJson(chatJson as Map<String, dynamic>))
            .toList(),
      );
}

class AuthServiceException implements Exception {
  final String message;
  final int? statusCode;

  AuthServiceException(this.message, [this.statusCode]);

  @override
  String toString() => 'AuthServiceException: $message${statusCode != null ? ' ($statusCode)' : ''}';
}

class AuthService {
  final ApiConfig _config;
  final http.Client _client;

  AuthService({
    ApiConfig? config,
    http.Client? client,
  })  : _config = config ?? ApiConfig.development(),
        _client = client ?? http.Client();

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return password.length >= 6;
  }

  Future<ApiResponse<Map<String, dynamic>>> _makeRequest(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final uri = Uri.parse('${_config.baseUrl}$path');
      final headers = {
        ...ApiConfig.defaultHeaders,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final request = http.Request(method, uri);
      request.headers.addAll(headers);
      
      if (body != null) {
        request.body = json.encode(body);
      }

      final streamedResponse = await _client.send(request).timeout(
            _config.requestTimeout,
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.body.isEmpty) {
        return ApiResponse.error(
          'Empty response from server',
          response.statusCode,
        );
      }

      Map<String, dynamic>? responseBody;
      try {
        responseBody = json.decode(response.body) as Map<String, dynamic>;
      } on FormatException {
        return ApiResponse.error(
          'Invalid JSON response',
          response.statusCode,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(
          responseBody,
          response.statusCode,
        );
      } else {
        final errorMessage = responseBody['error']?.toString() ??
            _handleHttpError(response.statusCode);
        return ApiResponse.error(errorMessage, response.statusCode);
      }
    } on TimeoutException {
      return ApiResponse.error('Request timeout');
    } on http.ClientException catch (e) {
      return ApiResponse.error('Network error: ${e.message}');
    } catch (e) {
      return ApiResponse.error('Unexpected error: ${e.toString()}');
    }
  }

  String _handleHttpError(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Invalid credentials';
      case 403:
        return 'Access denied';
      case 404:
        return 'Resource not found';
      case 409:
        return 'User already exists';
      case 422:
        return 'Validation error';
      case 500:
        return 'Server error';
      default:
        return 'Error: $statusCode';
    }
  }

  Future<ApiResponse<LoginResponse>> login(
    String email,
    String password,
  ) async {
    if (!_isValidEmail(email)) {
      return ApiResponse.error('Please enter a valid email');
    }
    
    if (!_isValidPassword(password)) {
      return ApiResponse.error('Password must be at least 6 characters');
    }

    final result = await _makeRequest(
      '/api/auth/login',
      method: 'POST',
      body: {'email': email, 'password': password},
    );

    if (result.success) {
      try {
        final loginResponse = LoginResponse.fromJson(result.data!);
        return ApiResponse.success(loginResponse, result.statusCode);
      } catch (e) {
        return ApiResponse.error('Failed to parse server response');
      }
    } else {
      return ApiResponse.error(result.error!);
    }
  }

  Future<ApiResponse<String>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    if (username.isEmpty) {
      return ApiResponse.error('Please enter username');
    }
    
    if (!_isValidEmail(email)) {
      return ApiResponse.error('Please enter a valid email');
    }
    
    if (!_isValidPassword(password)) {
      return ApiResponse.error('Password must be at least 6 characters');
    }

    final result = await _makeRequest(
      '/api/auth/register',
      method: 'POST',
      body: {
        'username': username,
        'email': email,
        'password': password,
      },
    );

    if (result.success) {
      final message = result.data?['message']?.toString() ?? 'Registration successful';
      return ApiResponse.success(message, result.statusCode);
    } else {
      return ApiResponse.error(result.error!);
    }
  }

  Future<ApiResponse<LoginResponse>> verifyToken(String token) async {
    if (token.length < 100) {
      return ApiResponse.error('Invalid token');
    }

    final result = await _makeRequest(
      '/api/auth/initial-data',
      method: 'GET',
      token: token,
    );

    if (result.success) {
      try {

        final data = {
          ...(result.data as Map<String, dynamic>),
          'token': token,
        };
        
        final loginResponse = LoginResponse.fromJson(data);
        return ApiResponse.success(loginResponse, result.statusCode);
      } catch (e) {
        return ApiResponse.error('Failed to parse server response');
      }
    } else {
      return ApiResponse.error(result.error!);
    }
  }

  void dispose() {
    _client.close();
  }
}