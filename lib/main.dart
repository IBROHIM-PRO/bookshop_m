import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/reader/reader_home.dart';
import 'screens/parent/parent_dashboard.dart';
import 'screens/teacher/teacher_dashboard.dart';
import 'services/fcm_service.dart';

import 'services/local_notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService().init();
  await FcmService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final isBw = themeProvider.isBlackAndWhite;
          return MaterialApp(
            title: 'Китобхонаи Хонавода',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: isBw
                ? ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.dark,
                    scaffoldBackgroundColor: Colors.black,
                    appBarTheme: const AppBarTheme(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    colorScheme: const ColorScheme.dark(
                      primary: Colors.white,
                      onPrimary: Colors.black,
                      surface: Color(0xFF111111),
                      background: Colors.black,
                    ),
                    textTheme: const TextTheme(
                      bodyLarge: TextStyle(color: Colors.white),
                      bodyMedium: TextStyle(color: Colors.white70),
                    ),
                    elevatedButtonTheme: ElevatedButtonThemeData(
                      style: ElevatedButtonThemeFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  )
                : ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.dark,
                    scaffoldBackgroundColor: const Color(0xFF0F0C20),
                    appBarTheme: const AppBarTheme(
                      backgroundColor: Color(0xFF15102A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: Colors.deepPurpleAccent,
                      brightness: Brightness.dark,
                      background: const Color(0xFF0F0C20),
                      surface: const Color(0xFF15102A),
                    ),
                    textTheme: const TextTheme(
                      bodyLarge: TextStyle(color: Colors.white70),
                      bodyMedium: TextStyle(color: Colors.white60),
                    ),
                    elevatedButtonTheme: ElevatedButtonThemeData(
                      style: ElevatedButtonThemeFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

// ✅ ИСЛОҲ: StatelessWidget -> StatefulWidget
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // ✅ Future як маротиба дар initState сохта мешавад
  late final Future<bool> _autoLoginFuture;

  @override
  void initState() {
    super.initState();
    // listen: false — чунки мо дар initState ҳастем, на build
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _autoLoginFuture = authProvider.tryAutoLogin();
  }

  Widget _buildHomeByRole(String? role) {
    if (role == 'Parent') return const ParentDashboardScreen();
    if (role == 'Teacher') return const TeacherDashboardScreen();
    return const ReaderHomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ listen: true — барои ба навшавии authProvider вокуниш нишон додан
    final authProvider = Provider.of<AuthProvider>(context);
    // ✅ listen: false — танҳо барои хондани rang, rebuild лозим нест
    final isBw = Provider.of<ThemeProvider>(context, listen: false).isBlackAndWhite;

    // Агар аллакай authentication шуда бошад — фавран ба home гузар
    if (authProvider.isAuthenticated) {
      return _buildHomeByRole(authProvider.currentUser?.role);
    }

    return FutureBuilder<bool>(
      // ✅ _autoLoginFuture — ҳамеша ҳамон Future, нав сохта намешавад
      future: _autoLoginFuture,
      builder: (context, snapshot) {
        // Лоадинг
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: isBw ? Colors.black : const Color(0xFF0F0C20),
            body: Center(
              child: CircularProgressIndicator(
                color: isBw ? Colors.white : Colors.deepPurpleAccent,
              ),
            ),
          );
        }

        // Auto-login муваффақ шуд
        if (snapshot.data == true) {
          return _buildHomeByRole(authProvider.currentUser?.role);
        }

        // Auto-login нашуд — login screen
        return const LoginScreen();
      },
    );
  }
}

// Helper барои button style
ButtonStyle ElevatedButtonThemeFrom({
  required Color backgroundColor,
  required Color foregroundColor,
  required OutlinedBorder shape,
  required EdgeInsetsGeometry padding,
}) {
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.all<Color>(backgroundColor),
    foregroundColor: WidgetStateProperty.all<Color>(foregroundColor),
    shape: WidgetStateProperty.all<OutlinedBorder>(shape),
    padding: WidgetStateProperty.all<EdgeInsetsGeometry>(padding),
  );
}