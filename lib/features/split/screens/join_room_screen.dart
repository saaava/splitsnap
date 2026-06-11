import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splitsnap/core/theme/app_theme.dart';
import 'package:splitsnap/core/services/room_service.dart';
import 'package:splitsnap/features/split/screens/bill_confirmation_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _hasJoined = false;
  String? _errorMessage;
  String _storeName = '';
  String _createdBy = '';
  String _date = '';
  List<Map<String, dynamic>> _items = [];

  int get _myTotal => _items
      .where((i) => i['checked'] as bool)
      .fold(0, (sum, i) => sum + (i['totalPrice'] as int? ?? 0));

  String _formatRupiah(int amount) {
    if (amount == 0) return 'Rp 0';
    final str = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return 'Rp. ${buf.toString()}';
  }

  void _updateQty(int index, int delta) {
    setState(() {
      final current = _items[index]['quantity'] as int;
      final newQty = (current + delta).clamp(1, 99);
      final unitPrice = _items[index]['unitPrice'] as int? ?? 0;
      _items[index]['quantity'] = newQty;
      _items[index]['totalPrice'] = unitPrice * newQty;
    });
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Masukkan kode room terlebih dahulu',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final roomData = await RoomService.getRoom(code);
      if (roomData == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Kode room "$code" tidak ditemukan. Cek kembali kodenya.';
        });
        return;
      }
      final rawItems = (roomData['items'] as List<dynamic>?) ?? [];
      final items = rawItems.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final qty = map['quantity'] as int? ?? 1;
        final unitPrice = map['unitPrice'] as int? ?? 0;
        return {
          'name': map['name'] as String? ?? '',
          'quantity': qty,
          'unitPrice': unitPrice,
          'totalPrice': unitPrice * qty,
          'checked': false,
        };
      }).toList();
      setState(() {
        _storeName = roomData['storeName'] as String? ?? 'Belanja';
        _createdBy = roomData['createdBy'] as String? ?? 'Seseorang';
        _date = roomData['date'] as String? ?? '';
        _items = items;
        _hasJoined = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal bergabung: ${e.toString()}';
      });
    }
  }

  void _payLater() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.schedule, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pilihan kamu tersimpan. Kamu bisa bayar nanti.',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  void _payNow() {
    if (_myTotal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pilih item yang kamu beli terlebih dahulu',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }

    // Ambil nama singkat dari createdBy (bisa uid, nanti diganti dengan nama)
    final creatorName = _createdBy.length > 20
        ? _createdBy.substring(0, 8)
        : _createdBy;

    // Format tanggal untuk display
    final displayDate = _date.isNotEmpty
        ? _date
        : _formatDisplayDate(DateTime.now());

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillConfirmationScreen(
          storeName: _storeName,
          createdBy: creatorName,
          date: displayDate,
          total: _myTotal,
        ),
      ),
    );
  }

  String _formatDisplayDate(DateTime dt) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
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
          'Gabung Room',
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
            _buildJoinCard(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorBanner(),
            ],
            if (_hasJoined) ...[
              const SizedBox(height: 20),
              // Info banner: pilihan tersimpan otomatis
              _buildInfoBanner(),
              const SizedBox(height: 12),
              _buildChecklistSection(),
              const SizedBox(height: 16),
              _buildMyTotal(),
              const SizedBox(height: 16),
              _buildPaymentButtons(),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Text(
          'Gabung Room Split',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Masukkan kode dari temanmu',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 5,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            color: AppColors.primary,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '_ _ _ _ _',
            hintStyle: GoogleFonts.poppins(
              fontSize: 22,
              letterSpacing: 8,
              color: AppColors.textHint,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _joinRoom,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Gabung Sekarang',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    ),
  );

  Widget _buildErrorBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _errorMessage!,
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error),
          ),
        ),
      ],
    ),
  );

  Widget _buildInfoBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.success.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.success.withOpacity(0.3)),
    ),
    // child: Row(children: [
    //   Container(
    //     width: 22,
    //     height: 22,
    //     decoration: BoxDecoration(
    //       color: AppColors.success.withOpacity(0.15),
    //       borderRadius: BorderRadius.circular(6),
    //     ),
    //     child: Icon(Icons.check, color: AppColors.success, size: 14),
    //   ),
    //   const SizedBox(width: 10),
    //   Expanded(
    //     child: Text(
    //       ""
    //       ),
    //     ),
    //   ),
    // ]),
  );

  Widget _buildChecklistSection() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Centang item yang kamu beli',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              _storeName,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final checked = item['checked'] as bool;
          final totalPrice = item['totalPrice'] as int? ?? 0;
          final unitPrice = item['unitPrice'] as int? ?? 0;
          final qty = item['quantity'] as int;
          final name = item['name'] as String? ?? '';

          return Column(
            children: [
              if (i > 0) Divider(color: AppColors.divider, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          setState(() => _items[i]['checked'] = !checked),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: checked
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: checked
                                ? AppColors.primary
                                : AppColors.divider,
                            width: 1.5,
                          ),
                        ),
                        child: checked
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: checked
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              decoration: checked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          Text(
                            '${_formatRupiah(unitPrice)} / pcs',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _qtyBtn(
                          Icons.remove,
                          qty > 1 ? () => _updateQty(i, -1) : null,
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$qty',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _qtyBtn(Icons.add, () => _updateQty(i, 1)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 68,
                      child: Text(
                        _formatRupiah(totalPrice),
                        textAlign: TextAlign.end,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: checked
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    ),
  );

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: onTap != null
            ? AppColors.primary.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(
        icon,
        size: 14,
        color: onTap != null ? AppColors.primary : Colors.grey,
      ),
    ),
  );

  Widget _buildMyTotal() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total tagihan saya:',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            ),
            Text(
              _formatRupiah(_myTotal),
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Icon(
          Icons.receipt_long_outlined,
          color: Colors.white.withOpacity(0.6),
          size: 32,
        ),
      ],
    ),
  );

  /// Dua tombol: Bayar Nanti & Bayar Sekarang (sesuai gambar 1)
  Widget _buildPaymentButtons() => Row(
    children: [
      // Bayar Nanti — outlined
      Expanded(
        child: GestureDetector(
          onTap: _payLater,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              'Bayar Nanti',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      // Bayar Sekarang — filled
      Expanded(
        child: GestureDetector(
          onTap: _payNow,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              'Bayar Sekarang',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
