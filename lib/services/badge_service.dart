import 'dart:convert';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class BadgeService {
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();

  Future<void> updateBadgeCount() async {
    try {
      final response = await ApiService.get('/api/notifications/unread-count');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final int count = data['count'] ?? 0;
        await setBadge(count);
      }
    } catch (e) {
      debugPrint('Failed to update badge count: $e');
    }
  }

  Future<void> setBadge(int count) async {
    try {
      await AppBadgePlus.updateBadge(count);
    } catch (e) {
      debugPrint('Error setting badge: $e');
    }
  }
}
