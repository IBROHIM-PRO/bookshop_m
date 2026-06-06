import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

typedef NotificationCallback = void Function(String title, String message);

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  NotificationCallback? onNotification;
  void Function(Map<String, dynamic> data)? onRawMessage;

  static String get _wsBaseUrl {
    if (kIsWeb) return 'ws://localhost:5179';
    try {
      if (Platform.isAndroid) return 'ws://192.168.0.105:5179';
    } catch (_) {}
    return 'ws://192.168.0.105:5179';
  }

  void connect(int userId, String role) {
    if (_isConnected) return;
    try {
      final uri = Uri.parse('$_wsBaseUrl/ws/notifications?userId=$userId&role=$role');
      _channel = IOWebSocketChannel.connect(uri);
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> data = jsonDecode(message as String);
            onRawMessage?.call(data);

            final type = data['type'] as String?;
            if (type != 'login_approval_request' && type != 'force_logout') {
              final title = data['title'] as String? ?? 'Паём';
              final msg = data['message'] as String? ?? '';
              onNotification?.call(title, msg);
            }
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
        },
        onError: (_) {
          _isConnected = false;
        },
      );
    } catch (_) {
      _isConnected = false;
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }
}
