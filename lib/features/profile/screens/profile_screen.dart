import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splitsnap/core/theme/app_theme.dart';
import 'package:splitsnap/features/auth/services/auth_service.dart';
import 'package:splitsnap/features/auth/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  User? _user;

  // Stats — nanti bisa disambungkan ke Firestore activity
  final int _totalTransaksi = 0;
  final int _totalSplitBill = 0;
  final int _totalNominal = 0;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
  }

  String get _displayName {
    if (_user?.displayName != null && _user!.displayName!.isNotEmpty) {
      return _user!.displayName!;
    }
    // Fallback: ambil bagian sebelum @ dari email
    final email = _user?.email ?? '';
    if (email.contains('@')) {
      final namePart = email.split('@').first;
      // Capitalize
      return namePart.isNotEmpty
          ? namePart[0].toUpperCase() + namePart.substring(1)
          : 'User';
    }
    return 'User';
  }

  String get _email => _user?.email ?? '-';

  String get _phone => _user?.phoneNumber ?? '-';

  String get _initials {
    final name = _displayName;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String _formatNominal(int amount) {
    if (amount == 0) return 'Rp 0';
    if (amount >= 1000000) {
      final jt = amount / 1000000;
      return 'Rp ${jt % 1 == 0 ? jt.toInt() : jt.toStringAsFixed(1)}jt';
    }
    if (amount >= 1000) {
      final rb = amount / 1000;
      return 'Rp ${rb % 1 == 0 ? rb.toInt() : rb.toStringAsFixed(1)}rb';
    }
    return 'Rp $amount';
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Keluar dari SplitSnap?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Kamu perlu login ulang untuk menggunakan aplikasi.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'Keluar',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profil',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Profile card
          _buildProfileCard(),
          const Spacer(),
          // Sign out button
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.of(context).padding.bottom + 20,
            ),
            child: _buildSignOutButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header section (foto + nama + email + no hp)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: const Color(0xFFD9BFC8), // warna muted rose seperti di gambar
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  alignment: Alignment.center,
                  child: _user?.photoURL != null
                      ? ClipOval(
                          child: Image.network(
                            _user!.photoURL!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildInitialsAvatar(),
                          ),
                        )
                      : _buildInitialsAvatar(),
                ),
                const SizedBox(height: 12),
                Text(
                  _displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _email,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.primaryDark,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _phone == '-' ? '' : _phone,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          // Stats row
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFEFE8EC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                _buildStatItem(
                  value: '$_totalTransaksi',
                  label: 'Transaksi',
                ),
                _buildStatDivider(),
                _buildStatItem(
                  value: '$_totalSplitBill',
                  label: 'Split Bill',
                ),
                _buildStatDivider(),
                _buildStatItem(
                  value: _formatNominal(_totalNominal),
                  label: 'Total',
                  isHighlighted: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    return Text(
      _initials,
      style: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    bool isHighlighted = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: isHighlighted ? 18 : 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.primary.withOpacity(0.2),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _signOut,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
        label: Text(
          'Sign out',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}