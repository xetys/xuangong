import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Xuan Gong burgundy color
    const burgundy = Color(0xFF9B1C1C);

    return MaterialApp(
      title: 'Xuan Gong',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Primary color - Xuan Gong burgundy
        primaryColor: burgundy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: burgundy,
          primary: burgundy,
          secondary: burgundy,
        ),

        // App bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: burgundy,
          elevation: 0,
          centerTitle: true,
        ),

        // Text theme - clean, readable
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
        ),

        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: burgundy, width: 2),
          ),
        ),

        // Card theme
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        // Use Material 3
        useMaterial3: true,

        // Font family (using default for now, can be customized)
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

// Splash screen to check auth state
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Small delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 500));

    final isLoggedIn = await _authService.isLoggedIn();

    if (mounted) {
      // Always go to login for MVP
      // In production, you'd fetch user data if logged in
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '玄功',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w300,
                color: burgundy,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(burgundy),
            ),
          ],
        ),
      ),
    );
  }
}
