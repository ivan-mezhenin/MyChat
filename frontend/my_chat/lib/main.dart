// main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_chat/screens/authentication_screen.dart';
import 'package:my_chat/screens/chats_screen.dart';
import 'package:my_chat/services/chat_service.dart';
import 'package:my_chat/services/auth_service.dart';
import 'package:my_chat/services/websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyChatApp());
}

class MyChatApp extends StatelessWidget {
  const MyChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Widget? _screen;
  String? _error;
  WebSocketService? _webSocketService;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _checkAuthAndNavigate();
    } catch (e) {
      _handleError('Ошибка инициализации: $e');
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      _navigateToAuth();
      return;
    }

    try {
      final authService = AuthService();
      
      final apiResponse = await authService.verifyToken(token)
          .timeout(const Duration(seconds: 10));

      if (!apiResponse.success || apiResponse.data == null) {
        await prefs.remove('auth_token');
        _navigateToAuth();
        return;
      }

      final result = apiResponse.data!;
      
      _webSocketService = WebSocketService();
      
      _setupWebSocketListeners();
      
      _connectWebSocket(token);

      _navigateToChats(
        chats: result.chats,
        userUID: result.user.uid,
      );
      
    } on TimeoutException {
      await prefs.remove('auth_token');
      _handleError('Превышено время ожидания сервера');
    } catch (e) {
      await prefs.remove('auth_token');
      _handleError('Ошибка авторизации: $e');
    }
  }

  void _setupWebSocketListeners() {
    if (_webSocketService == null) return;
    
    _connectionSubscription = _webSocketService!.connectionStream.listen((connected) {
      debugPrint('WebSocket connection status: $connected');
      if (!connected) {
        debugPrint('WebSocket disconnected');
      }
    });
      _webSocketService!.onNewChat = (data) {
    _handleNewChat(data);
  };
  }

  void _handleNewChat(Map<String, dynamic> data) {
  // Обновите экран чатов или покажите уведомление
  if (_screen is ChatsScreen) {
    final chatScreen = _screen as ChatsScreen;
    // Нужно добавить метод обновления в ChatsScreen
  }
}

  Future<void> _connectWebSocket(String token) async {
    try {
      await _webSocketService?.connect(token);
      debugPrint('WebSocket connection initiated');
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
    }
  }

  void _navigateToAuth() {
    if (!mounted) return;
    
    setState(() {
      _screen = const AuthenticationScreen();
    });
  }

  void _navigateToChats({required List<Chat> chats, required String userUID}) {
    if (!mounted || _webSocketService == null) return;
    
    setState(() {
      _screen = ChatsScreen(
        chats: chats,
        userUID: userUID,
        webSocketService: _webSocketService!,
      );
    });
  }

  void _handleError(String error) {
    debugPrint(error);
    
    if (!mounted) return;
    
    setState(() {
      _error = error;
      _screen = const AuthenticationScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    
    return _screen ?? const AuthenticationScreen();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    
    _webSocketService?.dispose();
    _webSocketService = null;
    
    super.dispose();
  }
}