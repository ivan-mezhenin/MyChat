import 'dart:async';

import 'package:my_chat/services/websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;
  WebSocketManager._internal();

  WebSocketService? _webSocketService;
  bool _isConnecting = false;
  Completer<void>? _connectionCompleter;
  String? _currentToken;
  bool _isDisposed = false;

  Future<WebSocketService> getService() async {
    if (_isDisposed) {
      throw Exception('WebSocketManager is disposed');
    }

    if (_webSocketService != null && _webSocketService!.isConnected) {
      return _webSocketService!;
    }

    if (_isConnecting && _connectionCompleter != null) {
      try {
        await _connectionCompleter!.future;
        return _webSocketService!;
      } catch (e) {
        return await _connect();
      }
    }

    return await _connect();
  }

  Future<WebSocketService> _connect() async {
    if (_isDisposed) {
      throw Exception('WebSocketManager is disposed');
    }

    _isConnecting = true;
    
    _connectionCompleter?.completeError('Connection cancelled');
    _connectionCompleter = Completer<void>();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found');
      }

      _currentToken = token;
      
      if (_webSocketService != null) {
          _webSocketService!.dispose();
        _webSocketService = null;
      }
      
      _webSocketService = WebSocketService();
      
      await _webSocketService!.connect(token);
      
      if (!_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete();
      }
      
      _isConnecting = false;
      return _webSocketService!;
    } catch (e) {
      _isConnecting = false;
      if (!_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(e);
      }
      rethrow;
    }
  }

  Future<void> reconnect() async {
    if (_currentToken != null && !_isDisposed) {
      await _connect();
    }
  }

  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    _currentToken = null;
    _isConnecting = false;
    
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError('Manager disposed');
    }
    _connectionCompleter = null;
    
    if (_webSocketService != null) {
        _webSocketService!.dispose();
      _webSocketService = null;
    }
  }

  bool get isConnected => _webSocketService?.isConnected ?? false;
  
  bool get isConnecting => _isConnecting;
}