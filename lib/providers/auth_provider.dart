import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('token') || !prefs.containsKey('user')) {
      return false;
    }

    final token = prefs.getString('token');
    final userData = jsonDecode(prefs.getString('user') ?? '{}');
    
    if (token == null || userData.isEmpty) {
      return false;
    }

    _currentUser = User.fromJson({
      ...userData,
      'token': token,
    });
    notifyListeners();
    return true;
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.post('/api/auth/login', {
        'email': email,
        'password': password,
      });

      final resData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _currentUser = User.fromJson(resData);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _currentUser!.token ?? '');
        await prefs.setString('user', jsonEncode(_currentUser!.toJson()));
        
        _isLoading = false;
        notifyListeners();
        return null; // No error
      } else {
        _isLoading = false;
        notifyListeners();
        return resData['message'] ?? 'Хатогӣ дар воридшавӣ';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Пайвастшавӣ бо сервер номумкин аст';
    }
  }

  Future<String?> register(String name, String email, String password, String role, String? phone) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.post('/api/auth/register', {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'phone': phone,
      });

      final resData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Registration is designed to work for Parents, Readers (or Admin registers them).
        // If the backend returns user object, auto log in if they aren't admin registering someone.
        // Let's check role.
        _currentUser = User.fromJson(resData);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _currentUser!.token ?? '');
        await prefs.setString('user', jsonEncode(_currentUser!.toJson()));
        
        _isLoading = false;
        notifyListeners();
        return null;
      } else {
        _isLoading = false;
        notifyListeners();
        return resData['message'] ?? 'Хатогӣ дар бақайдгирӣ';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Пайвастшавӣ бо сервер номумкин аст';
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    notifyListeners();
  }
}
