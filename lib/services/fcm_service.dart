import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  bool _isFirebaseInitialized = false;

  Future<void> init() async {
    try {
      // Firebase core has platform channels for Android/iOS/macOS/Web.
      // On unsupported platforms like Linux/Windows, we log and gracefully skip.
      if (kIsWeb || 
          defaultTargetPlatform == TargetPlatform.android || 
          defaultTargetPlatform == TargetPlatform.iOS || 
          defaultTargetPlatform == TargetPlatform.macOS) {
        
        await Firebase.initializeApp();
        _isFirebaseInitialized = true;
        
        // Request notifications permission
        NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          // Listen to foreground notifications
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
            // Can be handled dynamically or popped up in UI
            debugPrint('FCM Foreground message received: ${message.notification?.title}');
          });
        }
      } else {
        debugPrint('FCM is not supported on this platform: ${defaultTargetPlatform.toString()}');
      }
    } catch (e) {
      debugPrint('Firebase Core initialization skipped/failed: $e');
    }
  }

  Future<String?> getFcmToken() async {
    if (!_isFirebaseInitialized) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Failed to fetch FCM Token: $e');
      return null;
    }
  }

  Future<void> registerTokenWithBackend() async {
    if (!_isFirebaseInitialized) return;
    try {
      final token = await getFcmToken();
      if (token == null) return;

      final response = await ApiService.post('/api/notifications/fcm-token', {
        'token': token,
      });

      if (response.statusCode == 200) {
        debugPrint('FCM Token successfully registered with backend.');
      } else {
        debugPrint('Backend rejected FCM Token registration: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error registering FCM token with backend: $e');
    }
  }
}
