import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splitsnap/core/theme/app_theme.dart';

class CreateRoomScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String storeName;

  const CreateRoomScreen({
    super.key,
    required this.items,
    this.storeName = 'Belanja',
  });

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  late final String _roomCode;
  bool _reminderSent = false;

  // Peserta — index 0 = host (current user)
  final List<Map<String, dynamic>> _participants = [
    {'name': 'Novel', 'initials': 'NO', 'isPaid': true, 'status': 'Host', 'isHost': true},
    {'name': 'Bima', 'initials': 'BI', 'isPaid': true, 'status': 'Lunas', 'isHost': false},
    {'name': 'Sava', 'initials': 'SA', 'isPaid': false, 'status': 'Belum', 'isHost': false},
    {'name': 'Irene', 'initials': 'IR', 'isPaid': false, 'status': 'Belum', 'isHost': false},
  ];

  // Distribusi item ke peserta (simple round-robin dari items widget)
  late final List<Map<String, dynamic>> _bills;

  @override
  void initState() {
    super.initState();
    _roomCode = _generateCode();
    _bills = _buildBills();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(5, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  List<Map<String, dynamic>> _buildBills() {
    // Distribusi items ke 4 peserta secara round-robin
    final result = List.generate(
        _participants.length,
        (i) => {
              'name': _participants[i]['name'],
              'items': <Map<String, dynamic>>[],
              'paid': _participants[i]['isPaid'],
            });

    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final targetIdx = i % _participants.length;
      (result[targetIdx]['items'] as List).add(item);
    }
    return result;
  }

  int _billTotal(int idx) {
    final items = _bills[idx]['items'] as List<Map<String, dynamic>>;
    return items.fold(0, (sum, item) => sum + (item['totalPrice'] as int? ?? 0));
  }

  String _itemsSummary(int idx) {
    final items = _bills[idx]['items'] as List<Map<String, dynamic>>;
    if (items.isEmpty) return '-';
    return items.map((i) {
      final name = i['name'] as String;
      final qty = i['quantity'] as int? ?? 1;
      final short = name.split(' ').first;
      return qty > 1 ? '$short x$qty' : short;
    }).join(', ');
  }

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

  void _sendReminder() {
    final unpaid = _participants
        .where((p) => !(p['isPaid'] as bool) && !(p['isHost'] as bool))
        .map((p) => p['name'] as String)
        .toList();

    if (unpaid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Semua peserta sudah lunas! 🎉',
            style: GoogleFonts.poppins(fontSize: 12)),
        backgroundColor: AppColors.success,
      ));
      return;
    }

    setState(() => _reminderSent = true);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pengingat dikirim ke ${unpaid.join(' & ')} 🔔',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.primary,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildRoomCodeBanner(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(0),
                    topRight: Radius.circular(0),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildParticipantsSection(),
                      const SizedBox(height: 28),
                      _buildBillBreakdown(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildReminderButton(),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.storeName,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Dibuat oleh ${_participants.first['name']} · ${_participants.length} peserta',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCodeBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _roomCode,
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 8,
              ),
            ),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _roomCode));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Kode $_roomCode disalin ✓',
                      style: GoogleFonts.poppins(fontSize: 12)),
                  backgroundColor: AppColors.primaryDark,
                  duration: const Duration(seconds: 2),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  'Salin Kode',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Peserta',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Fitur undang segera hadir',
                      style: GoogleFonts.poppins(fontSize: 12)),
                  backgroundColor: AppColors.primary,
                ));
              },
              child: Text(
                '+Undang',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _participants.asMap().entries.map((entry) {
            final p = entry.value;
            final isPaid = p['isPaid'] as bool;
            final isHost = p['isHost'] as bool;
            return Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPaid
                        ? AppColors.accent.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.15),
                    border: isHost
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    p['initials'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p['name'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  p['status'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPaid ? AppColors.success : const Color(0xFF854F0B),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBillBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tagihan Per Orang',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        ..._bills.asMap().entries.map((entry) {
          final i = entry.key;
          final bill = entry.value;
          final isPaid = bill['paid'] as bool;
          final total = _billTotal(i);
          final isHost = _participants[i]['isHost'] as bool;

          return Column(
            children: [
              if (i > 0) Divider(color: AppColors.divider, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isHost
                                ? '${bill['name']} (kamu)'
                                : bill['name'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _itemsSummary(i),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatRupiah(total),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPaid ? 'Lunas' : 'Belum',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isPaid ? AppColors.success : const Color(0xFF854F0B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildReminderButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      color: Colors.white,
      child: GestureDetector(
        onTap: _sendReminder,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _reminderSent
                    ? Icons.check_circle_outline
                    : Icons.notifications_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _reminderSent ? 'Pengingat Terkirim ✓' : 'Kirim Pengingat',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}