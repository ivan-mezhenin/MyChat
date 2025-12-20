import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_chat/services/auth_service.dart';
import 'package:my_chat/screens/chats_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_chat/services/websocket_service.dart'; 

class AuthenticationScreen extends StatefulWidget {
  final WebSocketService? webSocketService;
  
  const AuthenticationScreen({super.key, this.webSocketService});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  
  late AuthService _authService;
  bool _isLogin = true;
  bool _isProcessing = false;
  WebSocketService? _webSocketService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _webSocketService = widget.webSocketService;
    
    debugPrint('AuthenticationScreen initState - WebSocketService: ${_webSocketService != null ? "reusing" : "new"}');
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    debugPrint('Token saved to SharedPreferences');
  }

  Future<void> _authenticate() async {
    if (_isProcessing) return;
    if (!_validateInputs()) return;
    
    setState(() => _isProcessing = true);
    debugPrint('Starting authentication...');

    try {
      if (_isLogin) {
        await _performLogin();
      } else {
        await _performRegistration();
      }
    } on SocketException {
      _showSnackBar('Нет подключения к интернету');
    } on TimeoutException {
      _showSnackBar('Превышено время ожидания');
    } catch (e) {
      debugPrint('Authentication error: $e');
      _showSnackBar('Произошла ошибка: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  bool _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Пожалуйста, заполните все поля');
      return false;
    }
    
    if (!_isLogin && _usernameController.text.trim().isEmpty) {
      _showSnackBar('Введите имя пользователя');
      return false;
    }
    
    return true;
  }
  
  Future<void> _performLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    debugPrint('Attempting login for: $email');
    
    final apiResponse = await _authService.login(email, password);
    
    if (apiResponse.success == true) {
      final loginResponse = apiResponse.data!;
      debugPrint('Login successful! Token received, user: ${loginResponse.user.uid}');
      debugPrint('Chats count: ${loginResponse.chats.length}');
      
      await _saveToken(loginResponse.token);
      
      if (_webSocketService != null) {
        try {
          debugPrint('Connecting WebSocket...');
          await _webSocketService!.connect(loginResponse.token);
          debugPrint('WebSocket connected');
        } catch (e) {
          debugPrint('WebSocket connection failed: $e');
        }
      }
      
      if (mounted) {
        debugPrint('Navigating to ChatsScreen...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatsScreen(
              chats: loginResponse.chats,
              userUID: loginResponse.user.uid,
              webSocketService: _webSocketService ?? WebSocketService(),
            ),
          ),
        );
      }
    } else {
      debugPrint('Login failed: ${apiResponse.error}');
      _showSnackBar('Ошибка: ${apiResponse.error}');
    }
  }

  Future<void> _performRegistration() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    debugPrint('Attempting registration: $username, $email');
    
    final apiResponse = await _authService.register(
      username: username,
      email: email,
      password: password,
    );
    
    if (apiResponse.success == true) {
      debugPrint('Registration successful');
      _showSnackBar('Регистрация успешна! Войдите в аккаунт.');
      if (mounted) {
        setState(() {
          _isLogin = true;
          _clearRegistrationFields();
        });
      }
    } else {
      debugPrint('Registration failed: ${apiResponse.error}');
      _showSnackBar('Ошибка: ${apiResponse.error}');
    }
  }

  void _clearRegistrationFields() {
    _usernameController.clear();
    _emailController.clear();
    _passwordController.clear();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Вход' : 'Регистрация'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isLogin) ...[
              TextField(
                controller: _usernameController,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Имя пользователя',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
                counterText: '',
              ),
            ),

            const SizedBox(height: 20),
            
            TextField(
              controller: _passwordController,
              obscureText: true,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Пароль',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                counterText: '',
              ),
            ),
            
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _authenticate,
                child: _isProcessing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
              ),
            ),
            
            const SizedBox(height: 20),
            
            TextButton(
              onPressed: _isProcessing ? null : () {
                setState(() {
                  _isLogin = !_isLogin;
                  if (_isLogin) {
                    _clearRegistrationFields();
                  } else {
                    _passwordController.clear();
                  }
                });
              },
              child: Text(
                _isLogin 
                  ? 'Нет аккаунта? Зарегистрироваться'
                  : 'Уже есть аккаунт? Войти',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('AuthenticationScreen dispose');
    
    // Очищаем только если этот экран создал WebSocketService
    if (widget.webSocketService == null && _webSocketService != null) {
      _webSocketService?.dispose();
    }
    
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    
    // AuthService не имеет dispose метода - удаляем эту строку!
    // _authService.dispose(); // <-- УДАЛИТЬ ЭТУ СТРОКУ!
    
    super.dispose();
  }
}