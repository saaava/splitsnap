import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splitsnap/core/theme/app_theme.dart';
import 'room_screen.dart';

class RoomShareScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String storeName;
  final String date;

  const RoomShareScreen({
    super.key,
    required this.items,
    required this.storeName,
    this.date = '',
  });

  @override
  State<RoomShareScreen> createState() => _RoomShareScreenState();
}

class _RoomShareScreenState extends State<RoomShareScreen> {
  late final String _roomCode;

  @override
  void initState() {
    super.initState();
    _roomCode = _generateCode();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(5, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  int get _grandTotal => widget.items.fold(
    0,
    (sum, item) => sum + ((item['totalPrice'] as int?) ?? 0),
  );

  String _formatRupiah(int amount) {
    if (amount == 0) return 'Rp 0';
    final str = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return 'Rp ${buf.toString()}';
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Kode $_roomCode disalin ✓',
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        backgroundColor: AppColors.primaryDark,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  void _goToRoom() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(
          roomCode: _roomCode,
          items: widget.items,
          storeName: widget.storeName,
          date: widget.date,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bagikan Room',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildCodeCard(),
            const SizedBox(height: 16),
            _buildBillCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  /// Hanya tampilkan kode room + tombol Salin Kode (tanpa QR, tanpa Bagikan)
  Widget _buildCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Kode Room',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Room code display
          Text(
            _roomCode.split('').join('  '),
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          // Hanya tombol Salin Kode
          GestureDetector(
            onTap: _copyCode,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Salin Kode',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard() {
    final displayDate = widget.date.isNotEmpty
        ? widget.date
        : _formatDisplayDate(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store + date header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.storeName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                displayDate,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Items list — TIDAK ada centang, tampil biasa
          ...widget.items.map((item) => _buildItemRow(item)),
          const SizedBox(height: 8),
          Divider(color: AppColors.divider, thickness: 1),
          const SizedBox(height: 8),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                _formatRupiah(_grandTotal),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '';
    final qty = item['quantity'] as int? ?? 1;
    final totalPrice = item['totalPrice'] as int? ?? 0;
    final displayName = qty > 1 ? '$name x$qty' : name;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            _formatRupiah(totalPrice),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _goToRoom,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            'Lihat Room',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDisplayDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
