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

  // ✅ Setup permission, channel, listener — TIDAK butuh login.
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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastSavedUid;

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

        final user = snapshot.data;

        if (user == null) {
          _lastSavedUid = null;
          return const LoginScreen();
        }

        // ✅ Simpan / refresh token FCM setiap kali ada user yang login,
        // tapi cukup sekali per sesi (hindari spam tiap rebuild widget).
        if (_lastSavedUid != user.uid) {
          _lastSavedUid = user.uid;
          // Jalankan setelah frame ini selesai agar tidak conflict
          // dengan build().
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.instance.saveToken();
          });
        }

        return const HomeScreen();
      },
    );
  }
}