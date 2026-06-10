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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
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
            _buildQRCard(),
            const SizedBox(height: 16),
            _buildBillCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildQRCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          // QR Code widget (generated from room code)
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: _QRPainter(data: _roomCode),
                size: const Size(200, 200),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Atau gunakan kode room',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          // Room code display
          Text(
            _roomCode.split('').join(' '),
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  label: 'Bagikan',
                  icon: Icons.share_rounded,
                  onTap: () {
                    // Share functionality placeholder
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Fitur share segera hadir',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  label: 'Salin Kode',
                  icon: Icons.copy_rounded,
                  onTap: _copyCode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
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
          // Items list
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
                  color: AppColors.textPrimary,
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
    final checked = item['checked'] as bool? ?? true;

    final displayName = qty > 1 ? '$name x$qty' : name;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: checked ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: checked ? AppColors.primary : AppColors.divider,
                width: 1.5,
              ),
            ),
            child: checked
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 12),
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
        20, 12, 20, MediaQuery.of(context).padding.bottom + 12,
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
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ─── Simple QR-like grid painter (visual only, not a real QR) ──────────────
// For a real QR, add the `qr_flutter` package and replace this with:
//   QrImageView(data: roomCode, version: QrVersions.auto, size: 200)
class _QRPainter extends CustomPainter {
  final String data;
  _QRPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // Use data string to seed a deterministic grid pattern
    final rng = _SeededRandom(data.codeUnits.fold(0, (a, b) => a * 31 + b));

    const modules = 21; // 21×21 QR-like grid
    final cellSize = size.width / modules;
    final quiet = cellSize; // quiet zone offset

    // Draw finder patterns (3 corners)
    _drawFinder(canvas, paint, 0, 0, cellSize);
    _drawFinder(canvas, paint, (modules - 7) * cellSize, 0, cellSize);
    _drawFinder(canvas, paint, 0, (modules - 7) * cellSize, cellSize);

    // Draw random data modules (skip finder zones)
    for (int row = 0; row < modules; row++) {
      for (int col = 0; col < modules; col++) {
        if (_isFinderZone(row, col, modules)) continue;
        if (rng.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(
              col * cellSize + 0.5,
              row * cellSize + 0.5,
              cellSize - 1,
              cellSize - 1,
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawFinder(Canvas canvas, Paint paint, double x, double y, double cell) {
    // Outer 7×7 black
    canvas.drawRect(Rect.fromLTWH(x, y, cell * 7, cell * 7), paint);
    // Inner 5×5 white
    final white = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(x + cell, y + cell, cell * 5, cell * 5), white);
    // Center 3×3 black
    canvas.drawRect(Rect.fromLTWH(x + cell * 2, y + cell * 2, cell * 3, cell * 3), paint);
  }

  bool _isFinderZone(int row, int col, int modules) {
    if (row < 8 && col < 8) return true;
    if (row < 8 && col >= modules - 8) return true;
    if (row >= modules - 8 && col < 8) return true;
    return false;
  }

  @override
  bool shouldRepaint(_QRPainter old) => old.data != data;
}

class _SeededRandom {
  int _seed;
  _SeededRandom(this._seed);
  bool nextBool() {
    _seed = (_seed * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (_seed & 1) == 0;
  }
}