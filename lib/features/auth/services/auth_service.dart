import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Stream<User?> get userStream => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ─── Register dengan Email & Password ───────────────────────────────────────
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
      // TIDAK signOut di sini, signOut dilakukan di register_screen
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  // ─── Login dengan Email & Password ──────────────────────────────────────────
  Future<UserCredential?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    for (int i = 0; i < 3; i++) {
      try {
        return await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        // Retry HANYA untuk masalah network, bukan salah credential
        if (i < 2 && e.code == 'network-request-failed') {
          await Future.delayed(Duration(seconds: i + 1));
          continue;
        }
        throw _handleFirebaseError(e);
      }
    }
    throw 'Login gagal, coba lagi.';
  }

  // ─── Login dengan Google ─────────────────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw 'Google Sign In gagal: idToken null. Pastikan SHA-1 sudah didaftarkan di Firebase.';
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Google Sign In error: $e';
    }
  }

  // ─── Logout ──────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ─── Handle Firebase Error ───────────────────────────────────────────────────
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
