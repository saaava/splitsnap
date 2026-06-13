import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splitsnap/core/services/room_service.dart';
import 'package:splitsnap/core/theme/app_theme.dart';
import 'package:splitsnap/features/auth/home/home_screen.dart';
import 'package:splitsnap/features/split/screens/bill_confirmation_screen.dart';

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

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

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

  /// Kirim pengingat — hanya host yang bisa akses tombol ini
  Future<void> _sendReminder(List<Map<String, dynamic>> participants) async {
    final unpaid = participants
        .where(
          (p) =>
              !(p['isPaid'] as bool? ?? false) &&
              !(p['isHost'] as bool? ?? false),
        )
        .toList();

    if (participants.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Belum ada peserta yang join.',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }

    if (unpaid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Semua peserta sudah lunas! 🎉',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }

    setState(() => _reminderSent = true);

    // Trigger Firestore flag (FCM akan diintegrasikan nanti)
    try {
      await RoomService.triggerPaymentReminder(widget.roomCode);
    } catch (_) {}

    if (!mounted) return;

    final names = unpaid.map((p) => p['name'] as String).join(' & ');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pengingat dikirim ke $names 🔔',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );

    // ✅ Setelah pengingat terkirim, arahkan host ke HomeScreen
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  /// Participant klik "Konfirmasi Pembayaran" → buka BillConfirmationScreen
  /// Setelah kembali (pop), markPaid dipanggil otomatis jika dikonfirmasi
  Future<void> _goToConfirmPayment(
    Map<String, dynamic> participant,
    int total,
  ) async {
    final displayDate = widget.date.isNotEmpty
        ? widget.date
        : _formatDisplayDate(DateTime.now());

    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BillConfirmationScreen(
          storeName: widget.storeName,
          createdBy: '',
          date: displayDate,
          total: total,
          roomCode: widget.roomCode,
          participantUid: participant['uid'] as String,
        ),
      ),
    );

    // Jika BillConfirmationScreen return true, markPaid sudah dipanggil di sana
    // RoomScreen akan auto-update via StreamBuilder karena Firestore realtime
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: RoomService.roomStream(widget.roomCode),
      builder: (context, snap) {
        List<Map<String, dynamic>> participants = [];
        bool isCurrentUserHost = false;

        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          participants = List<Map<String, dynamic>>.from(
            (data['participants'] as List<dynamic>? ?? []).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
          // Cek apakah user saat ini adalah host
          isCurrentUserHost = participants.any(
            (p) => p['uid'] == _currentUid && (p['isHost'] as bool? ?? false),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.primary,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(participants.length),
                _buildRoomCodeBanner(),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildParticipantsSection(participants),
                          const SizedBox(height: 28),
                          _buildBillBreakdown(participants),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ✅ Hanya tampilkan tombol pengingat untuk host
          bottomNavigationBar: isCurrentUserHost
              ? _buildReminderButton(participants)
              : null,
        );
      },
    );
  }

  Widget _buildTopBar(int participantCount) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
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
                participantCount == 0
                    ? 'Menunggu peserta bergabung...'
                    : '$participantCount peserta bergabung',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildRoomCodeBanner() => Padding(
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Kode ${widget.roomCode} disalin ✓',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  backgroundColor: AppColors.primaryDark,
                  duration: const Duration(seconds: 2),
                ),
              );
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

  Widget _buildParticipantsSection(List<Map<String, dynamic>> participants) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Peserta',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (participants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Icon(Icons.group_outlined, size: 40, color: AppColors.textHint),
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
                  'Bagikan kode room ke teman agar mereka bisa join',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        if (participants.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: participants.take(6).map((p) {
              final isPaid = p['isPaid'] as bool? ?? false;
              final isHost = p['isHost'] as bool? ?? false;
              final initials = p['initials'] as String? ?? '?';
              final name = p['name'] as String? ?? '';
              final shortName = name.split(' ').first;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPaid
                              ? AppColors.success.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.15),
                          border: isHost
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (isPaid)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    shortName,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildBillBreakdown(List<Map<String, dynamic>> participants) {
    final int grandTotal = widget.items.fold(
      0,
      (sum, item) => sum + ((item['totalPrice'] as int?) ?? 0),
    );

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
        if (participants.isEmpty)
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
                  'Total struk: ${_formatRupiah(grandTotal)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tagihan akan muncul setelah peserta memilih item',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        if (participants.isNotEmpty)
          ...participants.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final isPaid = p['isPaid'] as bool? ?? false;
            final isHost = p['isHost'] as bool? ?? false;
            final name = p['name'] as String? ?? '';
            final uid = p['uid'] as String? ?? '';

            final selectedItems = List<Map<String, dynamic>>.from(
              (p['selectedItems'] as List<dynamic>? ?? []).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            );
            final total =
                p['total'] as int? ??
                selectedItems.fold<int>(
                  0,
                  (sum, item) => sum + (item['totalPrice'] as int? ?? 0),
                );

            final isMe = uid == _currentUid;
            final hasSelected = selectedItems.isNotEmpty;

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
                              isMe ? '$name (kamu)' : name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isHost
                                  ? 'Pembuat Bill'
                                  : hasSelected
                                  ? selectedItems
                                        .map(
                                          (it) => (it['name'] as String)
                                              .split(' ')
                                              .take(2)
                                              .join(' '),
                                        )
                                        .join(', ')
                                  : 'Belum memilih item',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isHost
                                    ? AppColors.primary
                                    : hasSelected
                                    ? AppColors.textSecondary
                                    : AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Host tidak tampilkan nominal (dia tidak bayar ke siapa)
                          if (!isHost)
                            Text(
                              hasSelected ? _formatRupiah(total) : '—',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: hasSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textHint,
                              ),
                            ),
                          const SizedBox(height: 6),

                          // ✅ Tombol konfirmasi pembayaran hanya untuk:
                          // participant sendiri, bukan host, sudah pilih item, belum bayar
                          if (isMe && !isHost && hasSelected && !isPaid)
                            GestureDetector(
                              onTap: () => _goToConfirmPayment(p, total),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Konfirmasi Pembayaran',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          else if (!isHost)
                            Text(
                              isPaid
                                  ? 'Lunas ✓'
                                  : hasSelected
                                  ? 'Belum bayar'
                                  : '',
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

  /// Tombol kirim pengingat — hanya muncul untuk host
  Widget _buildReminderButton(List<Map<String, dynamic>> participants) =>
      Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        color: Colors.white,
        child: GestureDetector(
          onTap: () => _sendReminder(participants),
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
