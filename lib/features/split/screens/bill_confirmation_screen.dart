import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:splitsnap/core/services/room_service.dart';
import 'package:splitsnap/core/services/transaction_service.dart';
import 'package:splitsnap/core/theme/app_theme.dart';

class BillConfirmationScreen extends StatefulWidget {
  final String storeName;
  final String createdBy;
  final String date;
  final int total;
  final int participantCount;


  final String roomCode;
  final String participantUid;

  const BillConfirmationScreen({
    super.key,
    required this.storeName,
    required this.createdBy,
    required this.date,
    required this.total,
    this.participantCount = 1,
    this.roomCode = '',
    this.participantUid = '',
  });

  @override
  State<BillConfirmationScreen> createState() =>
      _BillConfirmationScreenState();
}

class _BillConfirmationScreenState extends State<BillConfirmationScreen> {
  int _selectedMethod = -1;
  File? _proofImage;
  bool _isUploading = false;

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

  Future<void> _pickProofImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1500,
    );
    if (xfile != null) {
      setState(() => _proofImage = File(xfile.path));
    }
  }

  void _handleManualConfirm() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Konfirmasi manual dikirim ke pembuat tagihan via WhatsApp',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        ]),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Future<void> _handleConfirmBill() async {
    if (_selectedMethod == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pilih metode konfirmasi terlebih dahulu',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }

    if (_selectedMethod == 1 && _proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Upload bukti transfer terlebih dahulu',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    // ✅ markPaid di Firestore agar RoomScreen realtime langsung update
    if (widget.roomCode.isNotEmpty && widget.participantUid.isNotEmpty) {
      try {
        await RoomService.markPaid(
          roomCode: widget.roomCode,
          uid: widget.participantUid,
        );
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isUploading = false);

    // Simpan ke TransactionService
    TransactionService.instance.addTransaction(
      TransactionItem(
        name: widget.storeName,
        date: 'Baru saja',
        people: '${widget.participantCount} orang',
        amount: widget.total,
        status: 'Lunas',
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFFE8F5E9),
        iconColor: const Color(0xFF2E7D32),
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.verified_outlined,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tagihan berhasil dikonfirmasi! ✅',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        ]),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );

    // ✅ Pop kembali ke RoomScreen (bukan pushAndRemoveUntil)
    // RoomScreen akan auto-refresh status via StreamBuilder
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.of(context).pop(true); // return true = konfirmasi berhasil
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Konfirmasi Tagihan',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total tagihan saya:',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: Colors.white70),
                  ),
                  Text(
                    _formatRupiah(widget.total),
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailCard(),
            const SizedBox(height: 20),
            Text(
              'METODE KONFIRMASI',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            _buildManualOption(),
            const SizedBox(height: 12),
            _buildUploadOption(),
            const SizedBox(height: 32),
            _buildConfirmButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Tagihan',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _detailRow('Room / Toko', widget.storeName),
          if (widget.createdBy.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailRow('Dibuat oleh', widget.createdBy),
          ],
          const SizedBox(height: 10),
          _detailRow('Tanggal', widget.date),
          Divider(color: AppColors.divider, height: 24),
          _detailRow('Total', _formatRupiah(widget.total), isBold: true),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? AppColors.primary : AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildManualOption() {
    final isSelected = _selectedMethod == 0;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEDF7ED) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.success : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.success.withOpacity(0.15)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color:
                    isSelected ? AppColors.success : AppColors.textHint,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Konfirmasi Manual',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  Text('Konfirmasi via WhatsApp ke pembuat tagihan',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (isSelected)
              GestureDetector(
                onTap: _handleManualConfirm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Kirim',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption() {
    final isSelected = _selectedMethod == 1;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEDF7ED) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.success : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.credit_card_outlined,
                        color: isSelected
                            ? AppColors.success
                            : AppColors.textHint,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upload Bukti Transfer',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        Text('Ambil foto bukti transfer dari galeri',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickProofImage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.success.withOpacity(0.15)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.success
                              : AppColors.divider,
                        ),
                      ),
                      child: Icon(Icons.upload_rounded,
                          color: isSelected
                              ? AppColors.success
                              : AppColors.textHint,
                          size: 20),
                    ),
                  ),
                ],
              ),
            ),
            if (_proofImage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: GestureDetector(
                  onTap: _pickProofImage,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _proofImage!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Ganti Foto',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_proofImage == null && isSelected)
              GestureDetector(
                onTap: _pickProofImage,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: AppColors.textHint, size: 28),
                          const SizedBox(height: 4),
                          Text('Pilih dari Galeri',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textHint)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _handleConfirmBill,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isUploading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text('Konfirmasi Tagihan',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
      ),
    );
  }
}