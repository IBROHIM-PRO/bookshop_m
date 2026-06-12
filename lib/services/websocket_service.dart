import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'api_service.dart';

typedef NotificationCallback = void Function(String title, String message, String category);

class WebSocketService {
  // Singleton pattern
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;

  // Stream for broadcasting raw messages
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  // ✅ userId ва role нигоҳ медорем барои retry
  int? _userId;
  String? _role;

  NotificationCallback? onNotification;
  void Function(Map<String, dynamic> data)? onRawMessage;

  void broadcastLocalMessage(Map<String, dynamic> data) {
    _messageController.add(data);
  }

  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  static const Duration _retryDelay = Duration(seconds: 3);
  static const Duration _connectionTimeout = Duration(seconds: 5);

  // ✅ Флаг барои пешгири аз reconnect баъд аз disconnect()
  bool _isDisposed = false;

  static String get _wsBaseUrl => ApiService.wsBaseUrl;

  bool get isConnected => _isConnected;

  void connect(int userId, String role) {
    if (_isConnected) return;
    if (_isDisposed) {
      // ✅ агар disconnect() шуда буд, reset мекунем
      _isDisposed = false;
    }

    // ✅ нигоҳ медорем барои retry
    _userId = userId;
    _role = role;

    _attemptConnection(userId, role);
  }

  void _attemptConnection(int userId, String role) {
    if (_isDisposed) return;

    try {
      final uri = Uri.parse(
        '$_wsBaseUrl/ws/notifications?userId=$userId&role=$role',
      );

      _channel = IOWebSocketChannel.connect(
        uri,
        connectTimeout: _connectionTimeout, // ✅ timeout дуруст
      );

      _subscription = _channel!.stream.listen(
        (message) {
          if (_isDisposed) return;
          try {
            final Map<String, dynamic> data = jsonDecode(message as String);
            _messageController.add(data); // Send to stream
            onRawMessage?.call(data);

            final type = data['type'] as String?;
            if (type != 'login_approval_request' &&
                type != 'force_logout' &&
                type != 'chat_message' &&
                type != 'chat_message_edit' &&
                type != 'chat_message_delete') {
              final title = data['title'] as String? ?? 'Паём';
              final msg = data['message'] as String? ?? '';
              final category = data['category'] as String? ?? 'Academic';
              onNotification?.call(title, msg, category);
            }
          } catch (e) {
            debugPrint('WebSocket message parse error: $e');
          }
        },
        onDone: () {
          debugPrint('WebSocket closed. Retrying...');
          _handleConnectionError();
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _handleConnectionError();
        },
        cancelOnError: true, // ✅ хато шуд — subscription бандем
      );

      _isConnected = true;
      _retryCount = 0;
      debugPrint('WebSocket connected: userId=$userId, role=$role');
    } catch (e) {
      debugPrint('WebSocket connect exception: $e');
      _handleConnectionError();
    }
  }

  void _handleConnectionError() {
    _isConnected = false;
    _subscription?.cancel();
    _channel?.sink.close();
    _subscription = null;
    _channel = null;

    if (_isDisposed) return; // ✅ disconnect() шуда буд — retry нашавад

    // Switch active host to try fallback IP
    ApiService.switchHost();

    // ✅ Retry бо userId ва role-и нигоҳдоштаем
    if (_retryCount < _maxRetries && _userId != null && _role != null) {
      _retryCount++;
      debugPrint('WebSocket retry $_retryCount/$_maxRetries...');
      _retryTimer?.cancel();
      _retryTimer = Timer(_retryDelay, () {
        if (!_isDisposed && _userId != null && _role != null) {
          _attemptConnection(_userId!, _role!);
        }
      });
    } else {
      debugPrint('WebSocket max retries reached. Giving up.');
    }
  }

  // ✅ reconnect — агар userId ва role маълум бошанд
  void reconnect() {
    if (_userId != null && _role != null) {
      disconnect();
      _isDisposed = false;
      connect(_userId!, _role!);
    }
  }

  void disconnect() {
    _isDisposed = true; // ✅ retry нашавад
    _retryTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _retryCount = 0;
    _retryTimer = null;
    _subscription = null;
    _channel = null;
    debugPrint('WebSocket disconnected.');
  }
}