import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_chat/services/auth_service.dart';
import 'package:my_chat/screens/chats_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> _authenticate() async {
    if (_isProcessing) return;
    if (!_validateInputs()) return;
    
    setState(() => _isProcessing = true);

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
    } catch (e, stackTrace) {
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
    
    final apiResponse = await _authService.login(email, password);
    
    if (apiResponse.success == true) {
      final loginResponse = apiResponse.data!;
      
      await _saveToken(loginResponse.token);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatsScreen(
              chats: loginResponse.chats,
              userUID: loginResponse.user.uid,
            ),
          ),
        );
      }
    } else {
      _showSnackBar('Ошибка: ${apiResponse.error}');
    }
  }

  Future<void> _performRegistration() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    final apiResponse = await _authService.register(
      username: username,
      email: email,
      password: password,
    );
    
    if (apiResponse.success == true) {
      _showSnackBar('Регистрация успешна! Войдите в аккаунт.');
      if (mounted) {
        setState(() {
          _isLogin = true;
          _clearRegistrationFields();
        });
      }
    } else {
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
      body: SingleChildScrollView(
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
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}