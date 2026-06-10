import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splitsnap/core/theme/app_theme.dart';

class RoomScreen extends StatefulWidget {
  final String roomCode;
  final List<Map<String, dynamic>> items;
  final String storeName;
  final String date;

  const RoomScreen({
    super.key,
    required this.roomCode,
    required this.items,
    required this.storeName,
    this.date = '',
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  bool _reminderSent = false;

  // Participants list - starts empty, grows as people join
  // Each participant: { name, initials, isPaid, isHost }
  // Host is YOU (the one who created the room) — added when first person joins
  // For now we simulate: tap "+Undang" to add a mock participant
  final List<Map<String, dynamic>> _participants = [];

  // Bills per participant (distributed when participants join)
  List<Map<String, dynamic>> _bills = [];

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
    return 'Rp. ${buf.toString()}';
  }

  void _redistributeItems() {
    if (_participants.isEmpty) {
      _bills = [];
      return;
    }

    _bills = List.generate(
      _participants.length,
      (i) => {
        'name': _participants[i]['name'],
        'items': <Map<String, dynamic>>[],
        'paid': _participants[i]['isPaid'],
        'isHost': _participants[i]['isHost'],
      },
    );

    for (int i = 0; i < widget.items.length; i++) {
      final targetIdx = i % _participants.length;
      (_bills[targetIdx]['items'] as List).add(widget.items[i]);
    }
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
      final short = name.split(' ').take(2).join(' ');
      return qty > 1 ? '$short x$qty' : short;
    }).join(', ');
  }

  // Simulate someone joining via code/QR
  void _simulateJoin(String name) {
    setState(() {
      final initials = name.length >= 2
          ? name.substring(0, 2).toUpperCase()
          : name.toUpperCase();

      final isFirst = _participants.isEmpty;
      _participants.add({
        'name': name,
        'initials': initials,
        'isPaid': isFirst, // host is auto-paid
        'isHost': isFirst,
        'status': isFirst ? 'Host' : 'Belum',
      });
      _redistributeItems();
    });
  }

  void _showJoinDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Simulasi Join',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan nama peserta yang join dengan kode:',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.roomCode,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Nama peserta...',
                hintStyle: GoogleFonts.poppins(color: AppColors.textHint),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                _simulateJoin(name);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'Tambah',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendReminder() {
    final unpaid = _participants
        .where((p) => !(p['isPaid'] as bool) && !(p['isHost'] as bool))
        .map((p) => p['name'] as String)
        .toList();

    if (_participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Belum ada peserta yang join.',
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      return;
    }

    if (unpaid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Semua peserta sudah lunas! 🎉',
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                decoration: const BoxDecoration(color: Colors.white),
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
                  _participants.isEmpty
                      ? 'Menunggu peserta bergabung...'
                      : 'Dibuat oleh ${_participants.first['name']} · ${_participants.length} peserta',
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
              widget.roomCode.split('').join(' '),
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 6,
              ),
            ),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.roomCode));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    'Kode ${widget.roomCode} disalin ✓',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
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
              onTap: _showJoinDialog,
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

        // Empty state
        if (_participants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.divider,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.group_add_outlined,
                  size: 40,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 12),
                Text(
                  'Belum ada peserta',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bagikan kode room agar teman bisa join',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _showJoinDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Simulasi Join',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Participant avatars
        if (_participants.isNotEmpty)
          Row(
            mainAxisAlignment: _participants.length <= 4
                ? MainAxisAlignment.spaceAround
                : MainAxisAlignment.start,
            children: _participants.take(6).map((p) {
              final isPaid = p['isPaid'] as bool;
              final isHost = p['isHost'] as bool;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
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
                        color: isPaid
                            ? AppColors.success
                            : const Color(0xFF854F0B),
                      ),
                    ),
                  ],
                ),
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
        const SizedBox(height: 12),

        // Empty bill state
        if (_participants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 32,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 8),
                Text(
                  'Total struk: ${_formatRupiah(_grandTotal)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tagihan akan dibagi setelah peserta bergabung',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

        // Bill per participant
        if (_participants.isNotEmpty)
          ..._bills.asMap().entries.map((entry) {
            final i = entry.key;
            final bill = entry.value;
            final isPaid = bill['paid'] as bool;
            final isHost = bill['isHost'] as bool;
            final total = _billTotal(i);

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
                              color: isPaid
                                  ? AppColors.success
                                  : const Color(0xFF854F0B),
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
        20, 12, 20, MediaQuery.of(context).padding.bottom + 12,
      ),
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