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

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  Widget? _screen;
  String? _error;
  WebSocketService? _webSocketService;
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
      _printDebug('App resumed, checking connection...');
      _checkConnection();
    } else if (state == AppLifecycleState.paused) {
      _printDebug('App paused');
    }
  }

  Future<void> _initializeApp() async {
    try {
      await _checkAuthAndNavigate();
    } catch (e, stackTrace) {
      _printDebug('Error initializing app: $e\n$stackTrace');
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
      
      // Создаем новый WebSocketService если нет
      _webSocketService ??= WebSocketService();
      
      _setupWebSocketListeners();
      
      // Подключаем WebSocket
      await _connectWebSocket(token);

      _navigateToChats(
        chats: result.chats,
        userUID: result.user.uid,
      );
      
    } on TimeoutException {
      await prefs.remove('auth_token');
      _handleError('Превышено время ожидания сервера');
    } catch (e, stackTrace) {
      _printDebug('Auth error: $e\n$stackTrace');
      await prefs.remove('auth_token');
      _handleError('Ошибка авторизации: ${e.toString()}');
    } finally {
      _isCheckingAuth = false;
    }
  }

void _setupWebSocketListeners() {
  if (_webSocketService == null) return;
  
  _connectionSubscription = _webSocketService!.connectionStream.listen((connected) {
    _printDebug('WebSocket connection status: $connected');
    
    if (!connected && mounted) {
      _printDebug('Connection lost, will try to reconnect...');
      
      // Попытка переподключения с задержкой
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_webSocketService!.isConnected) {
          _checkAndReconnect();
        }
      });
    }
  });
}
Future<void> _checkAndReconnect() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  
  if (token != null && _webSocketService != null && !_webSocketService!.isConnected) {
    _printDebug('Attempting to reconnect WebSocket...');
    try {
      await _webSocketService!.connect(token);
      _printDebug('WebSocket reconnected');
    } catch (e) {
      _printDebug('WebSocket reconnection failed: $e');
    }
  }
}

  Future<void> _connectWebSocket(String token) async {
    try {
      await _webSocketService?.connect(token);
      _printDebug('WebSocket connection initiated');
      
      // Ждем подключения
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e, stackTrace) {
      _printDebug('WebSocket connection error: $e\n$stackTrace');
      // Не блокируем навигацию при ошибке WebSocket
    }
  }

  Future<void> _scheduleReconnect() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted || _webSocketService == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token != null && _webSocketService!.isConnected == false) {
      _printDebug('Attempting to reconnect WebSocket...');
      await _connectWebSocket(token);
    }
  }

  Future<void> _checkConnection() async {
    if (_webSocketService != null && !_webSocketService!.isConnected) {
      _printDebug('Checking and restoring connection...');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token != null) {
        await _connectWebSocket(token);
      }
    }
  }

  void _navigateToAuth() {
    if (!mounted) return;
    
    _printDebug('Navigating to auth screen');
    
    setState(() {
      _screen = AuthenticationScreen(webSocketService: _webSocketService);
    });
  }

  void _navigateToChats({required List<Chat> chats, required String userUID}) {
    if (!mounted || _webSocketService == null) return;
    
    _printDebug('Navigating to chats screen, user: $userUID, chats: ${chats.length}');
    
    setState(() {
      _screen = ChatsScreen(
        chats: chats,
        userUID: userUID,
        webSocketService: _webSocketService!,
      );
    });
  }

  void _handleError(String error) {
    _printDebug(error);
    
    if (!mounted) return;
    
    setState(() {
      _error = error;
      _screen = const AuthenticationScreen();
    });
  }

  void _printDebug(String message) {
    debugPrint('[AuthWrapper] $message');
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
    
    _printDebug('Disposing WebSocketService');
    _webSocketService?.dispose();
    _webSocketService = null;
    
    super.dispose();
  }
}