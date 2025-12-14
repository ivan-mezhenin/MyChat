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
  
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isLogin = true;
  final TextEditingController _usernameController = TextEditingController();

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  void _authenticate() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Пожалуйста, заполните все поля');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    Map<String, dynamic> result;
    
    if (_isLogin) {
      result = await _authService.login(email, password);
    } else {
      final String username = _usernameController.text.trim();
      if (username.isEmpty) {
        _showSnackBar('Введите имя пользователя');
        setState(() { _isLoading = false; });
        return;
      }
      result = await _authService.register(username, email, password);
    }

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      if (_isLogin) {
        if (result['token'] != null) {
          await _saveToken(result['token']);
        }
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatsScreen(
                chats: result['chats'],
                userUID: result['user']['uid'],
              ),
            ),
          );
        }
      } else {
        _showSnackBar('Регистрация успешна! Войдите в аккаунт.');
        setState(() {
          _isLogin = true;
          _usernameController.clear();
        });
      }
    } else {
      _showSnackBar('Ошибка: ${result['error']}');
    }
  }

  void _showSnackBar(String message) {
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
                decoration: const InputDecoration(
                  labelText: 'Имя пользователя',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),

            const SizedBox(height: 20),
            
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Пароль',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _authenticate, // Просто блокируем кнопку
                child: Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
              ),
            ),
            
            const SizedBox(height: 20),
            
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                  if (_isLogin) {
                    _usernameController.clear();
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
}