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
  Widget? _screen;

  @override
  void initState() {
    super.initState();
    _determineScreen();
  }

  Future<void> _determineScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    Widget screen;
    
    if (token == null) {
      screen = const AuthenticationScreen();
    } else {
      try {
        final authService = AuthService();
        final result = await authService.verifyToken(token);
        
        if (result['success'] == true) {
          screen = ChatsScreen(
            chats: result['chats'] ?? [],
            userUID: result['user']['uid'],
          );
        } else {
          await prefs.remove('auth_token');
          screen = const AuthenticationScreen();
        }
      } catch (e) {
        screen = const AuthenticationScreen();
      }
    }
    
    if (mounted) {
      setState(() {
        _screen = screen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Пока не определили экран - ПУСТОТА
    return _screen ?? const SizedBox.shrink();
  }
}