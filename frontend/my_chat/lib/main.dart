import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_chat/screens/authentication_screen.dart';
import 'package:my_chat/screens/chats_screen.dart';
import 'package:my_chat/services/chat_service.dart';
import 'package:my_chat/services/auth_service.dart';
import 'package:my_chat/services/websocket_service.dart';
import 'package:my_chat/websocket_manager.dart';

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

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  Widget? _screen;
  final WebSocketManager _wsManager = WebSocketManager();
  StreamSubscription? _connectionSubscription;
  bool _isCheckingAuth = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      _checkConnection();
    }
  }

  Future<void> _initializeApp() async {
    try {
      await _checkAuthAndNavigate();
    } catch (e) {
      _handleError('Ошибка инициализации: ${e.toString()}');
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    if (_isCheckingAuth) return;
    
    _isCheckingAuth = true;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      _isCheckingAuth = false;
      _navigateToAuth();
      return;
    }

    try {
      final authService = AuthService();
      
      final apiResponse = await authService.verifyToken(token)
          .timeout(const Duration(seconds: 10));

      if (!apiResponse.success || apiResponse.data == null) {
        await prefs.remove('auth_token');
        _isCheckingAuth = false;
        _navigateToAuth();
        return;
      }

      final result = apiResponse.data!;
      
      try {
        final wsService = await _wsManager.getService();
        _setupWebSocketListeners(wsService);
      } catch (e) {
        debugPrint('WebSocket connection failed: $e');
      }

      _navigateToChats(
        chats: result.chats,
        userUID: result.user.uid,
      );
      
    } on TimeoutException {
      await prefs.remove('auth_token');
      _handleError('Превышено время ожидания сервера');
    } catch (e) {
      await prefs.remove('auth_token');
      _handleError('Ошибка авторизации: ${e.toString()}');
    } finally {
      _isCheckingAuth = false;
    }
  }

  void _setupWebSocketListeners(WebSocketService wsService) {
    _connectionSubscription = wsService.connectionStream.listen((connected) {
      if (!connected && mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _checkAndReconnect();
          }
        });
      }
    });
  }

  Future<void> _checkAndReconnect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token != null) {
      try {
        await _wsManager.reconnect();
      } catch (e) {
        debugPrint('WebSocket reconnection failed: $e');
      }
    }
  }

  Future<void> _checkConnection() async {
    if (!_wsManager.isConnected) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token != null) {
        try {
          await _wsManager.getService();
        } catch (e) {
          debugPrint('Connection restore failed: $e');
        }
      }
    }
  }

  void _navigateToAuth() {
    if (!mounted) return;
    
    setState(() {
      _screen = const AuthenticationScreen();
    });
  }

  void _navigateToChats({required List<Chat> chats, required String userUID}) {
    if (!mounted) return;
    
    setState(() {
      _screen = ChatsScreen(
        chats: chats,
        userUID: userUID,
      );
    });
  }

  void _handleError(String error) {
    if (!mounted) return;
    
    setState(() {
      _screen = const AuthenticationScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _screen ?? const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    
    _wsManager.dispose();
    
    super.dispose();
  }
}