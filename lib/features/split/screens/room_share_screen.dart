import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splitsnap/core/theme/app_theme.dart';
import 'package:splitsnap/features/split/services/room_service.dart';
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
  bool _isSaving = false;

  // Salinan items yang bisa dimodifikasi qty & checked-nya
  late List<Map<String, dynamic>> _editableItems;

  @override
  void initState() {
    super.initState();
    _roomCode = _generateCode();
    // Deep copy items, qty default dari struk, checked default false
    _editableItems = widget.items.map((item) => {
      'name': item['name'],
      'quantity': item['quantity'] as int? ?? 1,
      'unitPrice': item['unitPrice'] as int? ?? 0,
      'totalPrice': item['totalPrice'] as int? ?? 0,
      'checked': false,
    }).toList();
    _saveRoomToFirestore();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(5, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _saveRoomToFirestore() async {
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      // Simpan items asli dari struk (bukan editable) ke Firestore
      await RoomService.createRoom(
        roomCode: _roomCode,
        storeName: widget.storeName,
        date: widget.date,
        items: widget.items,
        createdBy: uid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menyimpan room: $e', style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _updateQty(int index, int delta) {
    setState(() {
      final current = _editableItems[index]['quantity'] as int;
      final newQty = (current + delta).clamp(1, 99);
      final unitPrice = _editableItems[index]['unitPrice'] as int;
      _editableItems[index]['quantity'] = newQty;
      _editableItems[index]['totalPrice'] = unitPrice * newQty;
    });
  }

  int get _selectedTotal => _editableItems
      .where((i) => i['checked'] as bool)
      .fold(0, (sum, i) => sum + (i['totalPrice'] as int? ?? 0));

  int get _grandTotal => widget.items.fold(0, (sum, i) => sum + ((i['totalPrice'] as int?) ?? 0));

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Kode $_roomCode disalin ✓', style: GoogleFonts.poppins(fontSize: 12)),
      backgroundColor: AppColors.primaryDark,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  void _goToRoom() {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => RoomScreen(
        roomCode: _roomCode,
        items: widget.items,
        storeName: widget.storeName,
        date: widget.date,
      ),
    ));
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
        title: Text('Bagikan Room',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _buildCodeCard(),
          const SizedBox(height: 16),
          _buildBillCard(),
          const SizedBox(height: 80),
        ]),
      ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Text('Kode Room', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        _isSaving
            ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            : Text(_roomCode.split('').join('  '),
                style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 4, color: AppColors.primary)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _isSaving ? null : _copyCode,
          child: Container(
            height: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider, width: 1.5)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.copy_rounded, size: 16, color: _isSaving ? AppColors.textHint : AppColors.primary),
              const SizedBox(width: 8),
              Text('Salin Kode', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600,
                  color: _isSaving ? AppColors.textHint : AppColors.primary)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildBillCard() {
    final displayDate = widget.date.isNotEmpty ? widget.date : _formatDisplayDate(DateTime.now());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(widget.storeName,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          Text(displayDate, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 16),
        // Items dengan checkbox + qty buttons
        ..._editableItems.asMap().entries.map((entry) => _buildItemRow(entry.key, entry.value)),
        const SizedBox(height: 8),
        Divider(color: AppColors.divider, thickness: 1),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(_formatRupiah(_grandTotal),
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
      ]),
    );
  }

  Widget _buildItemRow(int index, Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '';
    final qty = item['quantity'] as int;
    final unitPrice = item['unitPrice'] as int? ?? 0;
    final totalPrice = item['totalPrice'] as int? ?? 0;
    final checked = item['checked'] as bool;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        // Checkbox
        GestureDetector(
          onTap: () => setState(() => _editableItems[index]['checked'] = !checked),
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: checked ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: checked ? AppColors.primary : AppColors.divider, width: 1.5),
            ),
            child: checked ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
          ),
        ),
        const SizedBox(width: 10),
        // Nama + harga satuan
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text('${_formatRupiah(unitPrice)} / pcs',
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        // Tombol qty
        Row(children: [
          _qtyBtn(Icons.remove, qty > 1 ? () => _updateQty(index, -1) : null),
          SizedBox(width: 28, child: Text('$qty', textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          _qtyBtn(Icons.add, () => _updateQty(index, 1)),
        ]),
        const SizedBox(width: 8),
        // Total harga item
        SizedBox(width: 72, child: Text(_formatRupiah(totalPrice), textAlign: TextAlign.end,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: onTap != null ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 14, color: onTap != null ? AppColors.primary : Colors.grey),
    ),
  );

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3))]),
      child: GestureDetector(
        onTap: _isSaving ? null : _goToRoom,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: _isSaving ? AppColors.textHint : AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(_isSaving ? 'Menyimpan room...' : 'Lihat Room',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    );
  }

  String _formatDisplayDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}