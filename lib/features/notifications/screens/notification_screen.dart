import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splitsnap/core/services/room_service.dart';
import 'package:splitsnap/core/theme/app_theme.dart';
import 'package:splitsnap/features/split/screens/bill_confirmation_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> get _notifStream => _db
      .collection('notifications')
      .doc(_uid)
      .collection('items')
      .orderBy('createdAt', descending: true)
      .snapshots();

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'payment_reminder': return Icons.notifications_active_outlined;
      case 'payment_confirmed': return Icons.check_circle_outline;
      case 'room_invite': return Icons.group_add_outlined;
      default: return Icons.info_outline;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'payment_reminder': return const Color(0xFFFFF3E0);
      case 'payment_confirmed': return const Color(0xFFE8F5E9);
      case 'room_invite': return const Color(0xFFE3F2FD);
      default: return const Color(0xFFF5F5F5);
    }
  }

  Color _iconColorFor(String type) {
    switch (type) {
      case 'payment_reminder': return const Color(0xFFE65100);
      case 'payment_confirmed': return const Color(0xFF2E7D32);
      case 'room_invite': return const Color(0xFF1565C0);
      default: return Colors.grey;
    }
  }

  Future<void> _markAsRead(String docId) async {
    if (_uid.isEmpty) return;
    await _db
        .collection('notifications')
        .doc(_uid)
        .collection('items')
        .doc(docId)
        .update({'read': true});
  }

  Future<void> _markAllRead(List<QueryDocumentSnapshot> docs) async {
    if (_uid.isEmpty) return;
    final batch = _db.batch();
    for (final doc in docs) {
      if (!(doc['read'] as bool? ?? false)) {
        batch.update(doc.reference, {'read': true});
      }
    }
    await batch.commit();
  }

  /// "Bayar Sekarang" — tap dari notif payment_reminder.
  /// Ambil data room (storeName, items, date) dari Firestore lalu buka
  /// BillConfirmationScreen langsung untuk konfirmasi pembayaran.
  Future<void> _onBayarSekarang(Map<String, dynamic> data, String docId) async {
    final roomCode = data['roomCode'] as String? ?? '';
    if (roomCode.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final roomData = await RoomService.getRoom(roomCode);
      if (!mounted) return;
      Navigator.pop(context); // tutup loading

      if (roomData == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Room tidak ditemukan / sudah selesai',
              style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: AppColors.error,
        ));
        return;
      }

      final storeName = roomData['storeName'] as String? ?? (data['storeName'] as String? ?? 'Belanja');
      final date = roomData['date'] as String? ?? '';
      final amount = data['amount'] as int? ??
          (data['amount'] as num?)?.toInt() ?? 0;

      await _markAsRead(docId);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BillConfirmationScreen(
            storeName: storeName,
            createdBy: '',
            date: date,
            total: amount,
            roomCode: roomCode,
            participantUid: _uid,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal membuka room: $e', style: GoogleFonts.poppins(fontSize: 12)),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifikasi',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _notifStream,
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final hasUnread =
                  docs.any((d) => !(d['read'] as bool? ?? false));
              if (!hasUnread) return const SizedBox();
              return TextButton(
                onPressed: () => _markAllRead(docs),
                child: Text(
                  'Tandai semua',
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 12),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notifStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_none_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Belum ada notifikasi',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pengingat pembayaran akan muncul di sini',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[400]),
                ),
              ]),
            );
          }

          final today = <QueryDocumentSnapshot>[];
          final yesterday = <QueryDocumentSnapshot>[];
          final older = <QueryDocumentSnapshot>[];

          for (final doc in docs) {
            final ts = doc['createdAt'] as Timestamp?;
            if (ts == null) {
              older.add(doc);
              continue;
            }
            final diff = DateTime.now().difference(ts.toDate());
            if (diff.inDays == 0) {
              today.add(doc);
            } else if (diff.inDays == 1) {
              yesterday.add(doc);
            } else {
              older.add(doc);
            }
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              if (today.isNotEmpty) ...[
                _sectionHeader('Hari ini'),
                ...today.map((d) => _notifTile(d)),
              ],
              if (yesterday.isNotEmpty) ...[
                _sectionHeader('Kemarin'),
                ...yesterday.map((d) => _notifTile(d)),
              ],
              if (older.isNotEmpty) ...[
                _sectionHeader('Sebelumnya'),
                ...older.map((d) => _notifTile(d)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _notifTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] as String? ?? 'default';
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final isRead = data['read'] as bool? ?? false;
    final ts = data['createdAt'] as Timestamp?;

    return GestureDetector(
      onTap: () => _markAsRead(doc.id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppColors.primary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? Colors.grey.shade200
                : AppColors.primary.withOpacity(0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _colorFor(type),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconFor(type), color: _iconColorFor(type), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ]),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Text(
                  _timeAgo(ts),
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[400]),
                ),
              ]),
            ),
          ]),

          // ✅ Tombol aksi khusus payment_reminder
          if (type == 'payment_reminder') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _onBayarSekarang(data, doc.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Bayar Sekarang',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _markAsRead(doc.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Nanti',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}