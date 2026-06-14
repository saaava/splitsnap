import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:splitsnap/core/services/api_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Stream<User?> get userStream => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(fullName);
      await credential.user?.reload();
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    }

    try {
      await ApiService.instance.register(
        displayName: fullName,
        email: email,
        password: password,
      );
      debugPrint('Backend register ✅');
    } catch (e) {
      debugPrint('Backend register skip (mungkin sudah ada): $e');
    }
  }

  Future<UserCredential?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    UserCredential? credential;

    for (int i = 0; i < 3; i++) {
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        break;
      } on FirebaseAuthException catch (e) {
        if (i < 2 && e.code == 'network-request-failed') {
          await Future.delayed(Duration(seconds: i + 1));
          continue;
        }
        throw _handleFirebaseError(e);
      }
    }

    try {
      await ApiService.instance.login(email: email, password: password);
      debugPrint('JWT Railway tersimpan ✅');
    } catch (_) {
      try {
        final displayName =
            credential?.user?.displayName ?? email.split('@').first;
        await ApiService.instance.register(
          displayName: displayName,
          email: email,
          password: password,
        );
        await ApiService.instance.login(email: email, password: password);
        debugPrint('Backend auto-register + JWT tersimpan ✅');
      } catch (e) {
        debugPrint('Backend login gagal (lanjut pakai Firebase saja): $e');
      }
    }

    return credential;
  }

  Future<UserCredential?> signInWithGoogle() async {
    UserCredential? credential;

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw 'Google Sign In gagal: idToken null. Pastikan SHA-1 sudah didaftarkan di Firebase.';
      }

      final firebaseCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      credential = await _auth.signInWithCredential(firebaseCredential);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Google Sign In error: $e';
    }

    final email = credential.user?.email ?? '';
    final displayName =
        credential.user?.displayName ?? email.split('@').first;
    final password = 'google_${credential.user?.uid ?? ''}';

    try {
      await ApiService.instance.login(email: email, password: password);
      debugPrint('Google → JWT Railway tersimpan ✅');
    } catch (_) {
      try {
        await ApiService.instance.register(
          displayName: displayName,
          email: email,
          password: password,
        );
        await ApiService.instance.login(email: email, password: password);
        debugPrint('Google → Backend auto-register + JWT tersimpan ✅');
      } catch (e) {
        debugPrint('Google → Backend login gagal: $e');
      }
    }

    return credential;
  }

  Future<void> signOut() async {
    await ApiService.instance.logout(); 
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  String _handleFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan login.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Password terlalu lemah. Minimal 6 karakter.';
      case 'user-not-found':
        return 'Email tidak terdaftar.';
      case 'wrong-password':
        return 'Password salah. Coba lagi.';
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'network-request-failed':
        return 'Gagal terhubung ke internet.';
      case 'operation-not-allowed':
        return 'Metode login ini belum diaktifkan di Firebase Console.';
      default:
        return 'Error [${e.code}]: ${e.message}';
    }
  }
}