import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splitsnap/core/services/transaction_service.dart';
import 'package:splitsnap/core/services/api_service.dart';
import 'package:splitsnap/core/theme/app_theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _service = TransactionService.instance;

  // ── State dari API ────────────────────────────────────────────────
  int _apiBalance = 0;
  List<Map<String, dynamic>> _apiActivities = [];
  bool _isLoadingApi = true;

  @override
  void initState() {
    super.initState();
    _loadFromApi();
  }

  Future<void> _loadFromApi() async {
    setState(() => _isLoadingApi = true);
    try {
      final balRes = await ApiService.instance.getBalance();
      final actRes = await ApiService.instance.getWalletActivity();
      if (!mounted) return;
      setState(() {
        _apiBalance = (balRes['balance'] as num?)?.toInt() ?? 0;
        _apiActivities = List<Map<String, dynamic>>.from(
          (actRes['activities'] as List?) ?? [],
        );
      });
    } catch (e) {
      debugPrint('Load wallet API error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingApi = false);
    }
  }

  String _formatRupiah(int amount) {
    if (amount == 0) return 'Rp 0';
    final str = amount.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    final prefix = amount < 0 ? '-Rp ' : '+Rp ';
    return '$prefix${buf.toString()}';
  }

  String _formatRupiahBalance(int amount) {
    if (amount == 0) return 'Rp 0';
    final str = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return 'Rp ${buf.toString()}';
  }

  void _showTopUpDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Top Up Wallet',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Masukkan nominal (cth: 100000)',
            hintStyle: GoogleFonts.poppins(fontSize: 13),
            prefixText: 'Rp ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(
                    controller.text.replaceAll('.', '').replaceAll(',', ''),
                  ) ??
                  0;
              if (amount > 0) {
                // local dulu biar UI langsung update
                _service.topUpWallet(amount);
                Navigator.pop(context);

                // kirim ke API
                try {
                  final res = await ApiService.instance.topUp(amount);
                  debugPrint('API topUp OK: $res');
                } catch (e) {
                  debugPrint('API topUp error: $e');
                }

                // reload dari API supaya saldo & aktivitas sinkron
                await _loadFromApi();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Top up berhasil! +${_formatRupiahBalance(amount)}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Top Up',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Withdraw ke Bank',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo tersedia: ${_formatRupiahBalance(_apiBalance)}',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Nominal withdraw',
                hintStyle: GoogleFonts.poppins(fontSize: 13),
                prefixText: 'Rp ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(
                    controller.text.replaceAll('.', '').replaceAll(',', ''),
                  ) ??
                  0;
              if (amount > 0) {
                final ok = _service.withdrawWallet(amount);
                Navigator.pop(context);

                if (ok) {
                  try {
                    final res = await ApiService.instance.withdraw(amount);
                    debugPrint('API withdraw OK: $res');
                  } catch (e) {
                    debugPrint('API withdraw error: $e');
                  }

                  // reload dari API
                  await _loadFromApi();
                }

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Withdraw berhasil! Status: Pending'
                          : 'Saldo tidak cukup.',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    backgroundColor:
                        ok ? AppColors.primary : AppColors.error,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Withdraw',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Helper tampilkan aktivitas dari API ───────────────────────────
  IconData _iconForType(String type) {
    switch (type) {
      case 'topUp':
        return Icons.add_rounded;
      case 'withdraw':
        return Icons.remove_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Color _iconBgForType(String type) {
    switch (type) {
      case 'topUp':
        return const Color(0xFFE8F5E9);
      case 'withdraw':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFFFF3E0);
    }
  }

  Color _iconColorForType(String type) {
    switch (type) {
      case 'topUp':
        return const Color(0xFF2E7D32);
      case 'withdraw':
        return const Color(0xFF6B0F2B);
      default:
        return const Color(0xFFE65100);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Dompet',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // tombol refresh manual
                  IconButton(
                    onPressed: _loadFromApi,
                    icon: const Icon(Icons.refresh,
                        color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Balance card ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo Aktif',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _isLoadingApi
                        ? const SizedBox(
                            height: 36,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            _formatRupiahBalance(_apiBalance),
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                    const SizedBox(height: 10),
                    Text(
                      'SplitSnap Wallet',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '**** **** 4756',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                        Icon(Icons.account_balance_wallet_outlined,
                            color: AppColors.primary, size: 22),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Top Up / Withdraw buttons ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _showTopUpDialog,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Top Up',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showWithdrawDialog,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.south_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Withdraw',
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
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Activity list dari API ────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F4F5),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Text(
                        'Aktivitas Terakhir',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A0A0F),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _isLoadingApi
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : _apiActivities.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.receipt_long_outlined,
                                          size: 48,
                                          color: Colors.grey[300]),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Belum ada aktivitas',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 20),
                                  itemCount: _apiActivities.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, i) {
                                    final tx = _apiActivities[i];
                                    final type =
                                        tx['type'] as String? ?? '';
                                    final title =
                                        tx['title'] as String? ?? '';
                                    final date =
                                        tx['date'] as String? ?? '';
                                    final time =
                                        tx['time'] as String? ?? '';
                                    final amount =
                                        (tx['amount'] as num?)?.toInt() ??
                                            0;
                                    final status =
                                        tx['status'] as String? ?? '';
                                    final isPositive = amount > 0;
                                    final isPaid = status == 'Lunas';

                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color:
                                                  _iconBgForType(type),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      12),
                                            ),
                                            child: Icon(
                                              _iconForType(type),
                                              color:
                                                  _iconColorForType(type),
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                                Text(
                                                  title,
                                                  style:
                                                      GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: const Color(
                                                        0xFF1A0A0F),
                                                  ),
                                                ),
                                                Text(
                                                  '$date · $time',
                                                  style:
                                                      GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                isPaid
                                                    ? 'Lunas'
                                                    : 'Pending',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                  color: isPaid
                                                      ? AppColors.success
                                                      : const Color(
                                                          0xFFE65100),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatRupiah(amount),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: isPositive
                                                      ? AppColors.success
                                                      : AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}