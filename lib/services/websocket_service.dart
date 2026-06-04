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

  static String get _wsBaseUrl {
    if (kIsWeb) return 'ws://localhost:5179';
    try {
      if (Platform.isAndroid) return 'ws://10.0.2.2:5179';
    } catch (_) {}
    return 'ws://localhost:5179';
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
            final data = jsonDecode(message as String);
            final title = data['title'] as String? ?? 'Паём';
            final msg = data['message'] as String? ?? '';
            onNotification?.call(title, msg);
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
