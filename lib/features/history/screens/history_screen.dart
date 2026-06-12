// lib/features/history/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splitsnap/core/services/transaction_service.dart';
import 'package:splitsnap/core/theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // ── Filter state ──────────────────────────────────────────────────
  int _tabIndex = 0; // 0=Semua, 1=Pribadi, 2=Split Bill
  // Date range: default 7 hari terakhir
  DateTime _rangeEnd = DateTime.now();
  DateTime _rangeStart = DateTime.now().subtract(const Duration(days: 6));
  bool _isCustomRange = false;

  // ── Helpers ───────────────────────────────────────────────────────
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

  /// Parse 'DD Mon YYYY' → DateTime (dari TransactionService._formatDate)
  DateTime? _parseDate(String dateStr) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
      'Mei': 5, 'Jun': 6, 'Jul': 7, 'Agu': 8,
      'Sep': 9, 'Okt': 10, 'Nov': 11, 'Des': 12,
    };
    final parts = dateStr.trim().split(' ');
    if (parts.length < 3) return null;
    final day = int.tryParse(parts[0]);
    final month = months[parts[1]];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  bool _inRange(DateTime? dt) {
    if (dt == null) return false;
    final start = DateTime(_rangeStart.year, _rangeStart.month, _rangeStart.day);
    final end = DateTime(_rangeEnd.year, _rangeEnd.month, _rangeEnd.day, 23, 59);
    return !dt.isBefore(start) && !dt.isAfter(end);
  }

  // ── Filtered list ─────────────────────────────────────────────────
  List<TransactionItem> get _filtered {
    final all = TransactionService.instance.all;
    return all.where((tx) {
      // Tab filter
      if (_tabIndex == 1 && tx.type != TxType.pribadi) return false;
      if (_tabIndex == 2 && tx.type != TxType.splitBill) return false;
      // Date filter
      return _inRange(_parseDate(tx.date));
    }).toList();
  }

  // ── Chart data: amount per day in range ──────────────────────────
  List<_DayBar> _buildChartData() {
    final days = List.generate(7, (i) {
      return _rangeStart.add(Duration(days: i));
    });
    final filtered = _filtered;
    return days.map((day) {
      final label = _dayLabel(day);
      final total = filtered
          .where((tx) {
            final d = _parseDate(tx.date);
            return d != null &&
                d.year == day.year &&
                d.month == day.month &&
                d.day == day.day;
          })
          .fold(0, (sum, tx) => sum + tx.amount);
      return _DayBar(label: label, amount: total, date: day);
    }).toList();
  }

  String _dayLabel(DateTime dt) {
    const labels = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];
    return labels[dt.weekday - 1];
  }

  int get _totalPengeluaran =>
      _filtered.fold(0, (sum, tx) => sum + tx.amount);

  // ── Date picker ───────────────────────────────────────────────────
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF6B0F2B),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      // Clamp to max 7 days
      var end = picked.end;
      var start = picked.start;
      if (end.difference(start).inDays > 6) {
        end = start.add(const Duration(days: 6));
      }
      setState(() {
        _rangeStart = start;
        _rangeEnd = end;
        _isCustomRange = true;
      });
    }
  }

  void _setLast7Days() {
    setState(() {
      _rangeEnd = DateTime.now();
      _rangeStart = DateTime.now().subtract(const Duration(days: 6));
      _isCustomRange = false;
    });
  }

  String _rangeLabel() {
    if (!_isCustomRange) return '7 Hari Terakhir';
    final df = (DateTime dt) =>
        '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
    return '${df(_rangeStart)} – ${df(_rangeEnd)}';
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final chartData = _buildChartData();

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
          'Riwayat Transaksi',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [

          // ── Time range filter ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                const SizedBox(width: 50), 
                _timeChip(
                  label: '7 Hari Terakhir',
                  selected: !_isCustomRange,
                  onTap: _setLast7Days,
                ),
                const SizedBox(width: 8),
                _timeChip(
                  label: 'Pilih Tanggal',
                  selected: _isCustomRange,
                  onTap: _pickDateRange,
                  icon: Icons.calendar_today_outlined,
                ),
                if (_isCustomRange) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B0F2B).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _rangeLabel(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF6B0F2B),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Scrollable content ─────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Chart card ───────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Pengeluaran',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatRupiah(_totalPengeluaran),
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B0F2B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _BarChart(data: chartData),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Transaction list ─────────────────────────
                  if (filtered.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tx = filtered[index];
                        final isPribadi =
                            tx.type == TxType.pribadi;
                        final tagLabel =
                            isPribadi ? 'Pribadi' : tx.status;
                        final tagColor = isPribadi
                            ? AppColors.success
                            : (tx.status == 'Lunas'
                                ? AppColors.success
                                : const Color(0xFFE65100));

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tx.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    tagLabel,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: tagColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tx.subtitle,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tx.detail,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    _formatRupiah(tx.amount),
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
                      },
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6B0F2B)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6B0F2B),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF6B0F2B)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : const Color(0xFF6B0F2B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Tidak ada transaksi',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coba ubah filter atau rentang tanggal',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bar chart widget ──────────────────────────────────────────────────────

class _DayBar {
  final String label;
  final int amount;
  final DateTime date;
  _DayBar({required this.label, required this.amount, required this.date});
}

class _BarChart extends StatelessWidget {
  final List<_DayBar> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxAmount = data.map((d) => d.amount).fold(0, (a, b) => a > b ? a : b);
    final today = DateTime.now();

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((bar) {
          final ratio = maxAmount > 0 ? bar.amount / maxAmount : 0.0;
          final isToday = bar.date.year == today.year &&
              bar.date.month == today.month &&
              bar.date.day == today.day;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Amount label on top (only if > 0)
                  if (bar.amount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _shortAmount(bar.amount),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B0F2B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    height: bar.amount > 0
                        ? 20 + (ratio * 80)
                        : 6,
                    decoration: BoxDecoration(
                      color: bar.amount > 0
                          ? (isToday
                              ? const Color(0xFF6B0F2B)
                              : const Color(0xFF1A0A0F))
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bar.label,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isToday
                          ? const Color(0xFF6B0F2B)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _shortAmount(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return amount.toString();
  }
}