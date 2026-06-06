import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../services/websocket_service.dart';
import '../main.dart' show navigatorKey, AuthWrapper;

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _sessionExpiredMessage;
  WebSocketService? _wsService;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get sessionExpiredMessage => _sessionExpiredMessage;

  AuthProvider() {
    ApiService.onUnauthorized = () {
      if (_currentUser != null) {
        _sessionExpiredMessage = 'Шумо дар дастгоҳи дигар ворид шудед!';
        logout();
      }
    };
  }

  void clearSessionExpiredMessage() {
    _sessionExpiredMessage = null;
  }

  void _connectGlobalWebSocket(User user) {
    _wsService?.disconnect();
    _wsService = WebSocketService();
    
    _wsService!.onRawMessage = (data) {
      final type = data['type'] as String?;
      if (type == 'login_approval_request') {
        final requestId = data['requestId'] as String?;
        if (requestId != null) {
          _showApprovalDialog(requestId);
        }
      } else if (type == 'force_logout') {
        _sessionExpiredMessage = 'Шумо дар дастгоҳи дигар ворид шудед!';
        logout();
        
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    };
    
    _wsService!.connect(user.id, user.role);
  }

  void _showApprovalDialog(String requestId) {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _LoginApprovalDialog(
        requestId: requestId,
        onAccepted: () {
          _sessionExpiredMessage = 'Сессия дар дастгоҳи дигар фаъол карда шуд.';
          logout();
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (route) => false,
          );
        },
        onRejected: () {
          // Rejection handled inside dialog request
        },
      ),
    );
  }

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
    FcmService().registerTokenWithBackend();
    _connectGlobalWebSocket(_currentUser!);
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
        FcmService().registerTokenWithBackend();
        _connectGlobalWebSocket(_currentUser!);
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
        _currentUser = User.fromJson(resData);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _currentUser!.token ?? '');
        await prefs.setString('user', jsonEncode(_currentUser!.toJson()));
        
        _isLoading = false;
        notifyListeners();
        FcmService().registerTokenWithBackend();
        _connectGlobalWebSocket(_currentUser!);
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
    _wsService?.disconnect();
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    notifyListeners();
  }

  Future<void> updateCurrentUserImageUrl(String imageUrl) async {
    if (_currentUser == null) return;
    _currentUser = User(
      id: _currentUser!.id,
      name: _currentUser!.name,
      email: _currentUser!.email,
      phone: _currentUser!.phone,
      role: _currentUser!.role,
      token: _currentUser!.token,
      parentId: _currentUser!.parentId,
      imageUrl: imageUrl,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(_currentUser!.toJson()));
    notifyListeners();
  }
}

class _LoginApprovalDialog extends StatefulWidget {
  final String requestId;
  final VoidCallback onAccepted;
  final VoidCallback onRejected;

  const _LoginApprovalDialog({
    required this.requestId,
    required this.onAccepted,
    required this.onRejected,
  });

  @override
  State<_LoginApprovalDialog> createState() => _LoginApprovalDialogState();
}

class _LoginApprovalDialogState extends State<_LoginApprovalDialog> {
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        _respond(false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _respond(bool approve) async {
    if (_isResponding) return;
    setState(() {
      _isResponding = true;
    });
    _timer?.cancel();

    try {
      final response = await ApiService.post(
        '/api/auth/login/approve?requestId=${widget.requestId}&approve=$approve',
        {},
      );
      if (response.statusCode == 200) {
        if (approve) {
          widget.onAccepted();
        } else {
          widget.onRejected();
        }
      } else {
        widget.onRejected();
      }
    } catch (_) {
      widget.onRejected();
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E173E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.security_rounded, color: Colors.amber, size: 28),
          SizedBox(width: 10),
          Text(
            'Дархости воридшавӣ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Дастгоҳи дигар мехоҳад ба ҳисоби шумо ворид шавад. Агар қабул кунед, шумо аз ин дастгоҳ хориҷ мешавед.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Вақти боқимонда: $_secondsRemaining с.',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isResponding ? null : () => _respond(false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Рад кардан', style: TextStyle(color: Colors.white70)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isResponding ? null : () => _respond(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isResponding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Қабул кардан', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
