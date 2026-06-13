// lib/core/services/transaction_service.dart

import 'package:flutter/material.dart';

// ── Tipe transaksi untuk filter tab ──────────────────────────────────────
enum TxType { pribadi, splitBill }

class TransactionItem {
  final String name;
  final String date;
  final String people;
  final int amount;
  final String status;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final TxType type;

  // Baris subtitle di history card, mis: "22 April 2026 | Indomaret | 4 Peserta"
  final String subtitle;
  // Baris detail kiri, mis: "Bagianmu: Rp 29.000" atau nama toko
  final String detail;

  const TransactionItem({
    required this.name,
    required this.date,
    required this.people,
    required this.amount,
    required this.status,
    required this.icon,
    required this.color,
    required this.iconColor,
    this.type = TxType.splitBill,
    this.subtitle = '',
    this.detail = '',
  });

  TransactionItem copyWith({String? status}) {
    return TransactionItem(
      name: name,
      date: date,
      people: people,
      amount: amount,
      status: status ?? this.status,
      icon: icon,
      color: color,
      iconColor: iconColor,
      type: type,
      subtitle: subtitle,
      detail: detail,
    );
  }
}

// ─── Wallet Transaction ────────────────────────────────────────────────────

enum WalletTxType { topUp, withdraw, splitPay }

class WalletTransaction {
  final String title;
  final String date;
  final String time;
  final int amount; // positif = masuk, negatif = keluar
  final String status; // 'Lunas' | 'Pending'
  final WalletTxType type;

  const WalletTransaction({
    required this.title,
    required this.date,
    required this.time,
    required this.amount,
    required this.status,
    required this.type,
  });

  bool get isCredit => amount > 0;

  Color get iconBg => switch (type) {
        WalletTxType.topUp => const Color(0xFFE8F5E9),
        WalletTxType.withdraw => const Color(0xFFFFEBEE),
        WalletTxType.splitPay => const Color(0xFFFFF3E0),
      };

  Color get iconColor => switch (type) {
        WalletTxType.topUp => const Color(0xFF2E7D32),
        WalletTxType.withdraw => const Color(0xFF6B0F2B),
        WalletTxType.splitPay => const Color(0xFFE65100),
      };

  IconData get icon => switch (type) {
        WalletTxType.topUp => Icons.add_rounded,
        WalletTxType.withdraw => Icons.remove_rounded,
        WalletTxType.splitPay => Icons.receipt_long_outlined,
      };
}

// ─── Service ───────────────────────────────────────────────────────────────

class TransactionService {
  TransactionService._();
  static final TransactionService instance = TransactionService._();

  // ── Split bill / pribadi transactions ────────────────────────────
  final List<TransactionItem> _transactions = [];

  List<TransactionItem> get all => List.unmodifiable(_transactions);
  List<TransactionItem> get recent => _transactions.take(3).toList();

  void addTransaction(TransactionItem item) {
    _transactions.insert(0, item);
  }

  /// Tambah transaksi pribadi (dari "Simpan Pribadi" di ScanScreen)
  void addPrivateTransaction({
    required String storeName,
    required String date,
    required int amount,
    String locationHint = '',
  }) {
    final now = DateTime.now();
    final dateStr = date.isNotEmpty ? date : _formatDate(now);
    addTransaction(
      TransactionItem(
        name: storeName,
        date: dateStr,
        people: '1 Orang',
        amount: amount,
        status: 'Pribadi',
        icon: Icons.receipt_outlined,
        color: const Color(0xFFE8F5E9),
        iconColor: const Color(0xFF2E7D32),
        type: TxType.pribadi,
        subtitle: '$dateStr | ${_formatTime(now)}',
        detail: locationHint.isNotEmpty ? locationHint : storeName,
      ),
    );
  }

  void markPaid(String name) {
    final idx = _transactions.indexWhere((t) => t.name == name);
    if (idx != -1) {
      _transactions[idx] = _transactions[idx].copyWith(status: 'Lunas');
    }
  }

  void clear() => _transactions.clear();

  // ── Wallet ────────────────────────────────────────────────────────
  int _walletBalance = 0;
  final List<WalletTransaction> _walletTransactions = [];

  int get walletBalance => _walletBalance;
  List<WalletTransaction> get walletTransactions =>
      List.unmodifiable(_walletTransactions);

  void topUpWallet(int amount) {
    _walletBalance += amount;
    final now = DateTime.now();
    _walletTransactions.insert(
      0,
      WalletTransaction(
        title: 'Top Up Wallet',
        date: _formatDate(now),
        time: _formatTime(now),
        amount: amount,
        status: 'Lunas',
        type: WalletTxType.topUp,
      ),
    );
  }

  /// Returns false jika saldo tidak cukup
  bool withdrawWallet(int amount) {
    if (_walletBalance < amount) return false;
    _walletBalance -= amount;
    final now = DateTime.now();
    _walletTransactions.insert(
      0,
      WalletTransaction(
        title: 'Withdraw to Bank',
        date: _formatDate(now),
        time: _formatTime(now),
        amount: -amount,
        status: 'Pending',
        type: WalletTxType.withdraw,
      ),
    );
    return true;
  }

  void payWithWallet(String storeName, int amount) {
    if (_walletBalance >= amount) {
      _walletBalance -= amount;
    }
    final now = DateTime.now();
    _walletTransactions.insert(
      0,
      WalletTransaction(
        title: 'Bayar: $storeName',
        date: _formatDate(now),
        time: _formatTime(now),
        amount: -amount,
        status: 'Lunas',
        type: WalletTxType.splitPay,
      ),
    );
  }

  // ── Stats untuk Profile ───────────────────────────────────────────
  int get totalTransaksi => _transactions.length;
  int get totalSplitBill =>
      _transactions.where((t) => t.type == TxType.splitBill).length;
  int get totalNominal =>
      _transactions.fold(0, (sum, t) => sum + t.amount);

  // ── Date normalization ──────────────────────────────────────────
  /// Normalisasi berbagai format tanggal hasil OCR/struk (mis: '12/06/2026',
  /// '2026-06-12', '12.06.2026') menjadi format konsisten 'DD Mon YYYY'
  /// yang dipakai HistoryScreen untuk parsing tanggal & grafik.
  /// Jika tidak bisa diparse atau kosong, fallback ke tanggal hari ini.
  String normalizeDate(String raw) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return _formatDate(DateTime.now());

    // Sudah format 'DD Mon YYYY'
    if (RegExp(r'^\d{1,2}\s+[A-Za-z]{3}\s+\d{4}$').hasMatch(trimmed)) {
      return trimmed;
    }

    // 'DD/MM/YYYY', 'DD-MM-YYYY', 'DD.MM.YYYY' (juga YY 2 digit)
    final dmy = RegExp(r'^(\d{1,2})[./\-](\d{1,2})[./\-](\d{2,4})$')
        .firstMatch(trimmed);
    if (dmy != null) {
      final d = int.parse(dmy.group(1)!);
      final mo = int.parse(dmy.group(2)!);
      var y = int.parse(dmy.group(3)!);
      if (y < 100) y += 2000;
      if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
        return '$d ${months[mo - 1]} $y';
      }
    }

    // 'YYYY-MM-DD' atau 'YYYY/MM/DD'
    final ymd = RegExp(r'^(\d{4})[./\-](\d{1,2})[./\-](\d{1,2})$')
        .firstMatch(trimmed);
    if (ymd != null) {
      final y = int.parse(ymd.group(1)!);
      final mo = int.parse(ymd.group(2)!);
      final d = int.parse(ymd.group(3)!);
      if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
        return '$d ${months[mo - 1]} $y';
      }
    }

    // Format tak dikenal, fallback ke hari ini
    return _formatDate(DateTime.now());
  }

  // ── Helpers ───────────────────────────────────────────────────────
  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h.$m';
  }
}