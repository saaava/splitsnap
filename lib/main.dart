import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:splitsnap/core/services/notification_service.dart';
import 'package:splitsnap/core/theme/app_theme.dart';
import 'package:splitsnap/firebase_options.dart';
import 'package:splitsnap/features/auth/home/home_screen.dart';
import 'package:splitsnap/features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.instance.init();
  runApp(const SplitSnapApp());
}

class SplitSnapApp extends StatelessWidget {
  const SplitSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SplitSnap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B0F2B)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Terjadi kesalahan.\nSilakan restart aplikasi.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.data == null) {
          return const LoginScreen();
        }
        
        return const HomeScreen();
      },
    );
  }
}