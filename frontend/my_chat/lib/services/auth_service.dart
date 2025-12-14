import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiConfig {
  static const String baseUrl = 'http://192.168.1.104:8080';
  static const Duration requestTimeout = Duration(seconds: 10);
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
  };
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
}

class LoginResponse {
  final String token;
  final UserData user;
  final List<dynamic> chats;

  LoginResponse({
    required this.token,
    required this.user,
    required this.chats,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        token: json['token'] as String,
        user: UserData.fromJson(json['user'] as Map<String, dynamic>),
        chats: json['chats'] as List<dynamic>,
      );
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static final Uri _loginUri = Uri.parse('${ApiConfig.baseUrl}/api/auth/login');
  static final Uri _registerUri =
      Uri.parse('${ApiConfig.baseUrl}/api/auth/register');
  static final Uri _verifyTokenUri =
      Uri.parse('${ApiConfig.baseUrl}/api/auth/initial-data');


  final http.Client _client = http.Client();

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return password.length >= 6;
  }

  String _handleHttpError(int statusCode, String? errorMessage) {
    switch (statusCode) {
      case 400:
        return errorMessage ?? 'Некорректный запрос';
      case 401:
        return 'Неверные учетные данные';
      case 403:
        return 'Доступ запрещен';
      case 404:
        return 'Ресурс не найден';
      case 409:
        return 'Пользователь уже существует';
      case 500:
        return 'Ошибка сервера';
      default:
        return errorMessage ?? 'Ошибка: $statusCode';
    }
  }

  Map<String, dynamic>? _safeJsonDecode(String body) {
    try {
      return json.decode(body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> _makeRequest(
    Uri uri, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
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
            ApiConfig.requestTimeout,
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      final response = await http.Response.fromStream(streamedResponse);
      final responseBody = _safeJsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(
          responseBody ?? {},
          response.statusCode,
        );
      } else {
        final errorMessage = responseBody?['error']?.toString() ??
            _handleHttpError(response.statusCode, null);
        return ApiResponse.error(errorMessage, response.statusCode);
      }
    } on TimeoutException {
      return ApiResponse.error('Превышено время ожидания');
    } on FormatException {
      return ApiResponse.error('Ошибка формата данных');
    } catch (e) {
      return ApiResponse.error('Ошибка сети: ${e.toString()}');
    }
  }

  Future<ApiResponse<LoginResponse>> login(
    String email,
    String password,
  ) async {
    if (!_isValidEmail(email)) {
      return ApiResponse.error('Введите корректный email');
    }
    if (!_isValidPassword(password)) {
      return ApiResponse.error('Пароль должен содержать минимум 6 символов');
    }

    final result = await _makeRequest(
      _loginUri,
      method: 'POST',
      body: {'email': email, 'password': password},
    );

    if (result.success) {
      try {
        final loginResponse = LoginResponse.fromJson(result.data!);
        return ApiResponse.success(loginResponse, result.statusCode);
      } catch (e) {
        return ApiResponse.error('Ошибка обработки ответа сервера');
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
      return ApiResponse.error('Введите имя пользователя');
    }
    if (!_isValidEmail(email)) {
      return ApiResponse.error('Введите корректный email');
    }
    if (!_isValidPassword(password)) {
      return ApiResponse.error('Пароль должен содержать минимум 6 символов');
    }

    final result = await _makeRequest(
      _registerUri,
      method: 'POST',
      body: {
        'username': username,
        'email': email,
        'password': password,
      },
    );

    if (result.success) {
      final message = result.data?['message']?.toString() ?? 'Регистрация успешна';
      return ApiResponse.success(message, result.statusCode);
    } else {
      return ApiResponse.error(result.error!);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> verifyToken(String token) async {
    if (token.length < 100) {
      return ApiResponse.error('Невалидный токен');
    }

    final result = await _makeRequest(
      _verifyTokenUri,
      method: 'GET',
      token: token,
    );

    if (result.success) {
      final data = result.data!;
      return ApiResponse.success({
        'token': token,
        'user': UserData.fromJson(data['user'] as Map<String, dynamic>),
        'chats': data['chats'] as List<dynamic>,

      }, result.statusCode);
    } else {
      return ApiResponse.error(result.error!);
    }
  }

  void dispose() {
    _client.close();
  }
}