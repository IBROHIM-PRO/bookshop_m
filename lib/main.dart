import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
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
          final isDarkMode = themeProvider.isDarkMode;
          return MaterialApp(
            title: 'EduSpace',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFEBF3ED),
              cardColor: Colors.white,
              dividerColor: const Color(0xFFD1E2D5),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFEBF3ED),
                foregroundColor: Color(0xFF1A1F1C),
                elevation: 0,
                scrolledUnderElevation: 0,
                iconTheme: IconThemeData(color: Color(0xFF1A1F1C)),
                titleTextStyle: TextStyle(color: Color(0xFF1A1F1C), fontSize: 20, fontWeight: FontWeight.bold),
              ),
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF1E7431),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF1A1F1C),
                secondary: Color(0xFF228B22),
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Color(0xFF1A1F1C)),
                bodyMedium: TextStyle(color: Color(0xFF657367)),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return const Color(0xFFD1E2D5);
                    }
                    return const Color(0xFF1E7431);
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return const Color(0xFF657367).withOpacity(0.6);
                    }
                    return Colors.white;
                  }),
                  shape: WidgetStateProperty.all<OutlinedBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
                    const EdgeInsets.symmetric(vertical: 16),
                  ),
                  elevation: WidgetStateProperty.all<double>(0),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E7431),
                  side: const BorderSide(color: Color(0xFF1E7431)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: Colors.white,
                showDragHandle: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1E2D5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1E7431), width: 1.5),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              cardColor: const Color(0xFF1E1E2C),
              dividerColor: Colors.white12,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              colorScheme: const ColorScheme.dark(
                primary: Colors.white,
                onPrimary: Colors.black,
                surface: Colors.black,
                onSurface: Colors.white,
                secondary: Colors.white70,
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.white),
                bodyMedium: TextStyle(color: Colors.white70),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Future<bool> _autoLoginFuture;
  bool _isSplashFinished = false;
  bool? _isAuthed;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _autoLoginFuture = authProvider.tryAutoLogin();
  }

  Widget _buildHomeByRole(String? role) {
    if (role == 'Parent') return const ParentDashboardScreen();
    if (role == 'Teacher') return TeacherDashboardScreen();
    return const ReaderHomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    Widget activeScreen;
    if (authProvider.isAuthenticated) {
      activeScreen = _buildHomeByRole(authProvider.currentUser?.role);
    } else if (!_isSplashFinished) {
      activeScreen = SplashScreen(
        key: const ValueKey('splash_screen'),
        autoLoginFuture: _autoLoginFuture,
        onFinished: (isAuthed) {
          setState(() {
            _isSplashFinished = true;
            _isAuthed = isAuthed;
          });
        },
      );
    } else if (_isAuthed == true && authProvider.isAuthenticated) {
      activeScreen = _buildHomeByRole(authProvider.currentUser?.role);
    } else {
      activeScreen = const LoginScreen(key: ValueKey('login_screen'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: activeScreen,
    );
  }
}
