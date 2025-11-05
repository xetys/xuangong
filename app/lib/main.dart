import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().initialize();

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

    if (!mounted) return;

    if (isLoggedIn) {
      try {
        // Try to fetch user data with stored token
        final user = await _authService.getCurrentUser();

        if (mounted) {
          // Token is valid, navigate to HomeScreen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(user: user),
            ),
          );
        }
      } catch (e) {
        // Check if it's a network error or auth error
        final errorMessage = e.toString().toLowerCase();
        final isNetworkError = errorMessage.contains('failed host lookup') ||
            errorMessage.contains('network') ||
            errorMessage.contains('socket') ||
            errorMessage.contains('connection') ||
            errorMessage.contains('timeout');

        if (isNetworkError && mounted) {
          // Network error - show retry dialog
          _showNetworkErrorDialog();
        } else {
          // Token is invalid or other error - clear storage and go to login
          await _authService.logout();
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              ),
            );
          }
        }
      }
    } else {
      // Not logged in, go to login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Network Error'),
        content: const Text(
          'Unable to connect to the server. Please check your internet connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Retry authentication
              _checkAuthStatus();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              // Clear tokens and go to login
              await _authService.logout();
              if (mounted) {
                navigator.pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              }
            },
            child: const Text('Login Again'),
          ),
        ],
      ),
    );
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
