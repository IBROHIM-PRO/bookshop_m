import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/app_snackbar.dart';
import 'register_screen.dart';
import 'reader/reader_home.dart';
import 'parent/parent_dashboard.dart';
import 'teacher/teacher_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isPasswordVisible = false;
  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      setState(() {
        _isEmailFocused = _emailFocusNode.hasFocus;
      });
    });
    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.sessionExpiredMessage != null) {
        final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.black12),
            ),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: isDarkMode ? Colors.white : Colors.black),
                const SizedBox(width: 8),
                Text(
                  'Хатогӣ',
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              authProvider.sessionExpiredMessage!,
              style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  authProvider.clearSessionExpiredMessage();
                },
                child: Text(
                  'Фаҳмо',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Widget _buildHomeByRole(String? role) {
    if (role == 'Parent') return const ParentDashboardScreen();
    if (role == 'Teacher') return TeacherDashboardScreen();
    return const ReaderHomeScreen();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final error = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (error != null) {
      if (error.contains('Администратор')) {
        showDialog(
          context: context,
          builder: (ctx) => _AdminApprovalDialog(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          ),
        );
      } else {
        AppSnackBar.show(
          context,
          message: error,
          type: error.contains('суст') ? SnackBarType.warning : SnackBarType.error,
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _buildHomeByRole(authProvider.currentUser?.role),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoading = authProvider.isLoading;
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : const Color(0xFFF1F8F4);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Custom Logo Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/logo/Ellipse 2.svg',
                      width: 90,
                      height: 90,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EduSpase',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'serif', // Match the serif font in Figma
                            color: const Color(0xFF22873B),
                          ),
                        ),
                        Text(
                          'Маркази омузишӣ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'serif',
                            color: const Color(0xFF22873B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                Text(
                  'Воридшави ба барнома',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 24),
                // Phone Input
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w500),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Почтаи электрониро ворид кунед',
                    hintStyle: TextStyle(color: const Color(0xFF111827).withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.normal),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF22873B),
                    ),
                    filled: true,
                    fillColor: _isEmailFocused ? const Color(0xFFEDF9E8) : Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF22873B), width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Илтимос, почтаи электрониро ворид кунед';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password Input
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: !_isPasswordVisible,
                  style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w500),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => isLoading ? null : _submit(),
                  decoration: InputDecoration(
                    hintText: 'Паролро ворид кунед',
                    hintStyle: TextStyle(color: const Color(0xFF111827).withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.normal),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF22873B),
                    ),
                    filled: true,
                    fillColor: _isPasswordFocused ? const Color(0xFFEDF9E8) : Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF22873B), width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Паролро ворид кунед';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 52, // Increased height to prevent text from being cut off
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22873B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Figma corner radius 12
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Ворид шудан',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 80),
                const Text(
                  'Версияи 1.0',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminApprovalDialog extends StatefulWidget {
  final String email;
  final String password;

  const _AdminApprovalDialog({
    required this.email,
    required this.password,
  });

  @override
  State<_AdminApprovalDialog> createState() => _AdminApprovalDialogState();
}

class _AdminApprovalDialogState extends State<_AdminApprovalDialog> {
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  void _sendRequest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final response = await ApiService.post(
        '/api/auth/login/request-admin-access',
        {
          'email': widget.email,
          'password': widget.password,
        },
      );

      if (!mounted) return;

      final resData = jsonDecode(response.body) as Map<String, dynamic>;
      final message = resData['message'] as String?;

      setState(() {
        _isSuccess = response.statusCode == 200;
        _statusMessage = _isSuccess
            ? (message ?? 'Дархост муваффақона фиристода шуд!')
            : (message ?? 'Хатогӣ ҳангоми фиристодани дархост');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Хатогии пайвастшавӣ бо сервер.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    return AlertDialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: textColor.withOpacity(0.1)),
      ),
      title: Row(
        children: [
          Icon(Icons.admin_panel_settings_rounded, color: textColor, size: 28),
          const SizedBox(width: 10),
          Text(
            'Дархости доступ',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_statusMessage == null)
            Text(
              'Ин ҳисоб аллакай дар дастгоҳи дигар ворид шудааст ва дастгоҳи пештара фаъол нест. '
              'Шумо метавонед ба Администратор дархост фиристед, то сессияи пештараро тоза кунад.',
              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14, height: 1.4),
            )
          else
            Text(
              _statusMessage!,
              style: TextStyle(
                color: _isSuccess ? Colors.green : Colors.redAccent,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        if (_statusMessage == null)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: textColor.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Бекор кардан',
                    style: TextStyle(color: textColor.withOpacity(0.7)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textColor,
                    foregroundColor: backgroundColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: backgroundColor,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Фиристодан',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          )
        else
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: textColor,
                foregroundColor: backgroundColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
              child: const Text(
                'Фаҳмо',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
