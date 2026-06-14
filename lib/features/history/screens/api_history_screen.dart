// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:splitsnap/core/services/api_service.dart';
// import 'package:splitsnap/core/theme/app_theme.dart';

// class ApiHistoryScreen extends StatefulWidget {
//   const ApiHistoryScreen({super.key});

//   @override
//   State<ApiHistoryScreen> createState() => _ApiHistoryScreenState();
// }

// class _ApiHistoryScreenState extends State<ApiHistoryScreen> {
//   List<Map<String, dynamic>> _items = [];
//   bool _isLoading = true;
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Future<void> _load() async {
//     setState(() {
//       _isLoading = true;
//       _error = null;
//     });
//     try {
//       final data = await ApiService.instance.getTransactions();
//       setState(() {
//         _items = data;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _error = e.toString();
//         _isLoading = false;
//       });
//     }
//   }

//   String _formatRupiah(num amount) {
//     final str = amount.toInt().toString();
//     final buf = StringBuffer();
//     for (int i = 0; i < str.length; i++) {
//       if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
//       buf.write(str[i]);
//     }
//     return 'Rp $buf';
//   }

//   Future<void> _showAddDialog() async {
//     final nameController = TextEditingController();
//     final amountController = TextEditingController();

//     await showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: Text('Tambah Pengeluaran',
//             style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: nameController,
//               decoration: const InputDecoration(hintText: 'Nama / Toko'),
//             ),
//             const SizedBox(height: 12),
//             TextField(
//               controller: amountController,
//               keyboardType: TextInputType.number,
//               decoration: const InputDecoration(
//                 hintText: 'Nominal',
//                 prefixText: 'Rp ',
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Batal',
//                 style: GoogleFonts.poppins(color: AppColors.textSecondary)),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.primary,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8)),
//             ),
//             onPressed: () async {
//               final name = nameController.text.trim();
//               final amount =
//                   int.tryParse(amountController.text.trim()) ?? 0;
//               if (name.isEmpty || amount <= 0) return;

//               Navigator.pop(context);
//               try {
//                 await ApiService.instance.addTransaction(
//                   storeName: name,
//                   date: DateTime.now().toIso8601String().split('T').first,
//                   total: amount,
//                 );
//                 _load();
//               } catch (e) {
//                 if (!mounted) return;
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('$e')),
//                 );
//               }
//             },
//             child: Text('Simpan',
//                 style: GoogleFonts.poppins(
//                     color: Colors.white, fontWeight: FontWeight.w600)),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _delete(String id) async {
//     try {
//       await ApiService.instance.deleteTransaction(id);
//       _load();
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('$e')));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.primary,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new,
//               color: Colors.white, size: 20),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           'Riwayat (Server / API)',
//           style: GoogleFonts.poppins(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.w600),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh, color: Colors.white),
//             onPressed: _load,
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         backgroundColor: AppColors.primary,
//         onPressed: _showAddDialog,
//         child: const Icon(Icons.add, color: Colors.white),
//       ),
//       body: _isLoading
//           ? const Center(
//               child: CircularProgressIndicator(color: AppColors.primary))
//           : _error != null
//               ? Center(
//                   child: Padding(
//                     padding: const EdgeInsets.all(20),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Icon(Icons.error_outline,
//                             color: AppColors.error, size: 40),
//                         const SizedBox(height: 12),
//                         Text(_error!,
//                             textAlign: TextAlign.center,
//                             style: GoogleFonts.poppins(fontSize: 12)),
//                         const SizedBox(height: 12),
//                         ElevatedButton(
//                           onPressed: _load,
//                           style: ElevatedButton.styleFrom(
//                               backgroundColor: AppColors.primary),
//                           child: Text('Coba Lagi',
//                               style: GoogleFonts.poppins(color: Colors.white)),
//                         ),
//                       ],
//                     ),
//                   ),
//                 )
//               : _items.isEmpty
//                   ? Center(
//                       child: Text('Belum ada data dari server',
//                           style: GoogleFonts.poppins(
//                               color: Colors.grey[400], fontSize: 13)),
//                     )
//                   : ListView.separated(
//                       padding: const EdgeInsets.all(16),
//                       itemCount: _items.length,
//                       separatorBuilder: (_, __) => const SizedBox(height: 8),
//                       itemBuilder: (context, i) {
//                         final tx = _items[i];
//                         final id = tx['transaction_id'] as String;
//                         final name = tx['store_name'] as String? ?? '';
//                         final total = tx['total'] as num? ?? 0;
//                         final date = tx['date'] as String? ?? '';

//                         return Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 14, vertical: 12),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(12),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(0.04),
//                                 blurRadius: 6,
//                                 offset: const Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: Row(
//                             children: [
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment:
//                                       CrossAxisAlignment.start,
//                                   children: [
//                                     Text(name,
//                                         style: GoogleFonts.poppins(
//                                             fontSize: 13,
//                                             fontWeight: FontWeight.w600)),
//                                     Text(date,
//                                         style: GoogleFonts.poppins(
//                                             fontSize: 11,
//                                             color: AppColors.textSecondary)),
//                                   ],
//                                 ),
//                               ),
//                               Text(_formatRupiah(total),
//                                   style: GoogleFonts.poppins(
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.w700)),
//                               const SizedBox(width: 8),
//                               GestureDetector(
//                                 onTap: () => _delete(id),
//                                 child: const Icon(Icons.delete_outline,
//                                     color: AppColors.error, size: 20),
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                     ),
//     );
//   }
// }