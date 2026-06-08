import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splitsnap/core/theme/app_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static final List<Map<String, dynamic>> _history = [
    {
      'name': 'Makan Malam Geng',
      'date': 'Kemarin',
      'people': '3 orang',
      'amount': 145000,
      'status': 'Lunas',
      'icon': Icons.restaurant_outlined,
      'color': Color(0xFFE8F5E9),
      'iconColor': Color(0xFF2E7D32),
    },
    {
      'name': 'Belanja Indomaret',
      'date': '2 hari lalu',
      'people': '4 orang',
      'amount': 87500,
      'status': 'Menunggu',
      'icon': Icons.shopping_bag_outlined,
      'color': Color(0xFFFFF3E0),
      'iconColor': Color(0xFFE65100),
    },
    {
      'name': 'Kopi Bareng',
      'date': '3 hari lalu',
      'people': '2 orang',
      'amount': 54000,
      'status': 'Lunas',
      'icon': Icons.local_cafe_outlined,
      'color': Color(0xFFEDE7F6),
      'iconColor': Color(0xFF4527A0),
    },
    {
      'name': 'Bensin Motor',
      'date': '5 hari lalu',
      'people': '2 orang',
      'amount': 60000,
      'status': 'Lunas',
      'icon': Icons.local_gas_station_outlined,
      'color': Color(0xFFE3F2FD),
      'iconColor': Color(0xFF1565C0),
    },
  ];

  String _formatRupiah(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
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
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final tx = _history[index];
          final isPaid = tx['status'] == 'Lunas';
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
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tx['color'] as Color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tx['icon'] as IconData,
                    color: tx['iconColor'] as Color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx['name'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${tx['people']} · ${tx['date']}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
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
                      _formatRupiah(tx['amount'] as int),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? AppColors.success.withOpacity(0.1)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tx['status'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isPaid
                              ? AppColors.success
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
