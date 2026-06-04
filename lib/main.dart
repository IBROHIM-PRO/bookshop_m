import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/reader/reader_home.dart';
import 'screens/parent/parent_dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Китобхонаи Хонавода',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
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
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isAuthenticated) {
      final role = authProvider.currentUser?.role;
      if (role == 'Parent') {
        return const ParentDashboardScreen();
      } else {
        return const ReaderHomeScreen();
      }
    }

    return FutureBuilder<bool>(
      future: authProvider.tryAutoLogin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0C20),
            body: Center(
              child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
            ),
          );
        }

        if (snapshot.data == true) {
          final role = authProvider.currentUser?.role;
          if (role == 'Parent') {
            return const ParentDashboardScreen();
          } else {
            return const ReaderHomeScreen();
          }
        }

        return const LoginScreen();
      },
    );
  }
}

// Helper to construct button styles without using deprecated methods
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
