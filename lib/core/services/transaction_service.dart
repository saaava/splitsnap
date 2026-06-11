// lib/core/services/transaction_service.dart
// Singleton service untuk menyimpan riwayat transaksi in-memory
// (bisa diganti Firestore nanti)

import 'package:flutter/material.dart';

class TransactionItem {
  final String name;
  final String date;
  final String people;
  final int amount;
  final String status;
  final IconData icon;
  final Color color;
  final Color iconColor;

  const TransactionItem({
    required this.name,
    required this.date,
    required this.people,
    required this.amount,
    required this.status,
    required this.icon,
    required this.color,
    required this.iconColor,
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
    );
  }
}

class TransactionService {
  TransactionService._();
  static final TransactionService instance = TransactionService._();

  // List riwayat — kosong di awal, diisi saat user melakukan aktivitas
  final List<TransactionItem> _transactions = [];

  List<TransactionItem> get all => List.unmodifiable(_transactions);

  List<TransactionItem> get recent =>
      _transactions.take(3).toList();

  void addTransaction(TransactionItem item) {
    _transactions.insert(0, item);
  }

  void markPaid(String name) {
    final idx = _transactions.indexWhere((t) => t.name == name);
    if (idx != -1) {
      _transactions[idx] = _transactions[idx].copyWith(status: 'Lunas');
    }
  }

  void clear() => _transactions.clear();
}