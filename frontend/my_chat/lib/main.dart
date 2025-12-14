import 'package:flutter/material.dart';
import 'package:my_chat/screens/authentication_screen.dart';
import 'package:my_chat/screens/chats_screen.dart';
import 'package:my_chat/services/auth_service.dart';
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
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  Map<String, dynamic>? _authData;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final authService = AuthService();
    final result = await authService.verifyToken(token);
    
    if (result['success'] == true) {
      setState(() {
        _authData = result;
        _isLoading = false;
      });
    } else {
      await prefs.remove('auth_token');
      setState(() {
        _authData = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_authData != null && _authData!['user'] != null) {
      return ChatsScreen(
        chats: _authData!['chats'] ?? [],
        userUID: _authData!['user']['uid'],
      );
    }
    
    return const AuthenticationScreen();
  }
}