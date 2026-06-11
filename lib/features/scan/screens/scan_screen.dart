import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:splitsnap/core/theme/app_theme.dart';
import 'package:splitsnap/features/split/screens/room_share_screen.dart';
import 'package:splitsnap/features/history/screens/history_screen.dart';

class ReceiptItem {
  final String name;
  final int quantity;
  final int unitPrice;

  ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  int get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
      };
}

class ReceiptData {
  final String storeName;
  final String date;
  final List<ReceiptItem> items;
  final String? locationQuery;

  ReceiptData({
    required this.storeName,
    required this.date,
    required this.items,
    this.locationQuery,
  });

  int get total => items.fold(0, (sum, i) => sum + i.totalPrice);
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  ReceiptData? _receiptData;
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied && mounted) {
      _showSettingsDialog('Kamera', 'Izin kamera diperlukan untuk scan struk.');
    }
    return status.isGranted;
  }

  Future<bool> _requestGalleryPermission() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.photos.request();
      if (!status.isGranted) status = await Permission.storage.request();
    } else {
      status = await Permission.photos.request();
    }
    if (status.isPermanentlyDenied && mounted) {
      _showSettingsDialog('Galeri', 'Izin galeri diperlukan untuk memilih foto struk.');
    }
    return status.isGranted;
  }

  void _showSettingsDialog(String type, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Izin $type Diperlukan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); openAppSettings(); },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Buka Pengaturan', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    if (!await _requestCameraPermission()) return;
    final xfile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90, maxWidth: 2000);
    if (xfile != null) {
      setState(() { _imageFile = File(xfile.path); _receiptData = null; _errorMessage = null; });
      await _processImage();
    }
  }

  Future<void> _pickFromGallery() async {
    if (!await _requestGalleryPermission()) return;
    final xfile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 2000);
    if (xfile != null) {
      setState(() { _imageFile = File(xfile.path); _receiptData = null; _errorMessage = null; });
      await _processImage();
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final inputImage = InputImage.fromFile(_imageFile!);
      final textRecognizer = TextRecognizer();
      final recognized = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      setState(() { _receiptData = _parseReceiptText(recognized.text); _isLoading = false; });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = 'Gagal memproses struk: ${e.toString()}'; });
    }
  }

  ReceiptData _parseReceiptText(String rawText) {
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return ReceiptData(
      storeName: _extractStoreName(lines),
      date: _extractDate(lines),
      items: _extractItems(lines).isEmpty
          ? [ReceiptItem(name: 'Item tidak terdeteksi - coba foto lebih jelas', quantity: 1, unitPrice: 0)]
          : _extractItems(lines),
      locationQuery: _extractStoreName(lines) != 'Toko' ? _extractStoreName(lines) : null,
    );
  }

  String _extractStoreName(List<String> lines) {
    final filters = [
      RegExp(r'^\d{4}[-/]\d{2}[-/]\d{2}'),
      RegExp(r'^\d{2}:\d{2}'),
      RegExp(r'^\d+$'),
      RegExp(r'^\d{1,2}[./]\d{1,2}[./]\d{2,4}'),
    ];
    for (final line in lines.take(8)) {
      if (filters.any((p) => p.hasMatch(line))) continue;
      if (line.length < 3) continue;
      if (RegExp(r'^(Jl|Jalan|No\.|Jl\.)', caseSensitive: false).hasMatch(line)) continue;
      if (RegExp(r'^[\d\s.,]+$').hasMatch(line)) continue;
      if (RegExp(r'[a-zA-Z]').hasMatch(line)) return _cleanText(line);
    }
    return 'Toko';
  }

  String _extractDate(List<String> lines) {
    final patterns = [
      RegExp(r'\d{4}[-/]\d{1,2}[-/]\d{1,2}'),
      RegExp(r'\d{1,2}[-/]\d{1,2}[-/]\d{2,4}'),
      RegExp(r'\d{1,2}[.]\d{1,2}[.]\d{2,4}'),
      RegExp(r'\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{2,4}', caseSensitive: false),
    ];
    for (final line in lines) {
      for (final p in patterns) {
        final m = p.firstMatch(line);
        if (m != null) return m.group(0)!;
      }
    }
    return '';
  }

  List<ReceiptItem> _extractItems(List<String> lines) {
    final skipKeywords = RegExp(
      r'\b(total|tunai|kembali|kembal|ppn|pajak|tax|subtotal|sub\s*total|'
      r'cash|change|kembalian|bayar|bayaran|pembayaran|payment|'
      r'debit|kredit|credit|bca|mandiri|bri|bni|dana|ovo|gopay|shopeepay|'
      r'npwp|kasir|cashier|terima kasih|thank you|receipt|struk|invoice|nota|'
      r'grand total|service charge|harga total|jumlah|diskon|discount|'
      r'ongkos|ongkir|delivery|member|poin|point|tgl|tanggal|jam|waktu|'
      r'no\s*struk|no\s*nota|item qty|qty item|total qty|total item)\b',
      caseSensitive: false,
    );
    final dateLine = RegExp(r'^\d{1,2}[./]\d{1,2}[./]\d{2,4}');
    final priceRegex = RegExp(r'\b(\d{1,3}(?:[.,]\d{3})+|\d{4,7})\b');

    final formatCPattern = RegExp(r'^(\d{1,2})\s+([A-Za-z][A-Za-z\s/\-]+?)\s+([\d.,]{4,})$');
    int cCount = 0;
    for (final line in lines) { if (formatCPattern.hasMatch(line)) cCount++; }
    if (cCount >= 2) return _parseFormatC(lines, skipKeywords, priceRegex, dateLine);
    return _parseFormatAB(lines, skipKeywords, priceRegex, dateLine);
  }

  List<ReceiptItem> _parseFormatC(List<String> lines, RegExp skip, RegExp priceRegex, RegExp dateLine) {
    final items = <ReceiptItem>[];
    final lp = RegExp(r'^(\d{1,2})\s+(.+?)\s+([\d.,]{4,})\s*$');
    for (final line in lines) {
      if (skip.hasMatch(line.toLowerCase()) || dateLine.hasMatch(line)) continue;
      final m = lp.firstMatch(line);
      if (m == null) continue;
      final qty = int.tryParse(m.group(1)!) ?? 1;
      final price = int.tryParse(_normalizePrice(m.group(3)!)) ?? 0;
      if (price < 100 || price > 10000000) continue;
      final name = _cleanItemName(m.group(2)!.trim());
      if (name.length < 2) continue;
      items.add(ReceiptItem(name: name, quantity: qty, unitPrice: qty > 0 ? price ~/ qty : price));
    }
    return items;
  }

  List<ReceiptItem> _parseFormatAB(List<String> lines, RegExp skip, RegExp priceRegex, RegExp dateLine) {
    final items = <ReceiptItem>[];
    int footerStart = lines.length;
    for (int i = 0; i < lines.length; i++) {
      if (RegExp(r'^(subtotal|sub total|total\s*:?\s*[\d.,]+|tunai|kembali|terima kasih|thank you)').hasMatch(lines[i].toLowerCase().trim())) {
        footerStart = i; break;
      }
    }
    int i = 0;
    while (i < footerStart) {
      final line = lines[i];
      final ll = line.toLowerCase();
      if (dateLine.hasMatch(line) || skip.hasMatch(ll) || line.length < 2 || RegExp(r'^[-=*]+$').hasMatch(line)) { i++; continue; }

      final prices = priceRegex.allMatches(line).toList();
      if (prices.isNotEmpty) {
        final price = int.tryParse(_normalizePrice(prices.last.group(0)!)) ?? 0;
        if (price >= 100 && price <= 10000000) {
          String name = line.substring(0, prices.last.start).trim()
              .replaceAll(RegExp(r'\b[Rr][Pp]\.?\s*'), '').trim();
          int qty = 1;
          final qm = RegExp(r'\b(\d{1,2})\s*[xX@]\s*').firstMatch(name);
          if (qm != null) { qty = int.tryParse(qm.group(1)!) ?? 1; name = name.replaceFirst(qm.group(0)!, '').trim(); }
          name = _cleanItemName(name);
          if (name.length >= 2 && !skip.hasMatch(name.toLowerCase())) {
            items.add(ReceiptItem(name: name, quantity: qty, unitPrice: qty > 1 ? price ~/ qty : price));
          }
          i++; continue;
        }
      }

      if (i + 1 < footerStart) {
        final nextLine = lines[i + 1];
        final qpi = _parseQtyPriceLine(nextLine);
        if (qpi != null && !skip.hasMatch(ll) && RegExp(r'[a-zA-Z]').hasMatch(line) && line.length >= 3 && !RegExp(r'^\d{4}').hasMatch(line)) {
          final name = _cleanItemName(line);
          if (name.length >= 2 && qpi['unitPrice']! > 0) {
            items.add(ReceiptItem(name: name, quantity: qpi['qty']!, unitPrice: qpi['unitPrice']!));
            i += 2; continue;
          }
        }
      }
      i++;
    }
    return items;
  }

  Map<String, int>? _parseQtyPriceLine(String line) {
    final m = RegExp(r'^(\d{1,3})\s*(?:[a-zA-Z/]+\s+)?[xX@]\s*([\d.,]+)').firstMatch(line);
    if (m != null) {
      final qty = int.tryParse(m.group(1)!) ?? 1;
      final up = int.tryParse(_normalizePrice(m.group(2)!)) ?? 0;
      if (up >= 100 && up <= 5000000) return {'qty': qty, 'unitPrice': up};
    }
    final m2 = RegExp(r'^[Rr][Pp]\.?\s*([\d.,]+)\s*$').firstMatch(line.trim());
    if (m2 != null) {
      final p = int.tryParse(_normalizePrice(m2.group(1)!)) ?? 0;
      if (p >= 100 && p <= 10000000) return {'qty': 1, 'unitPrice': p};
    }
    return null;
  }

  String _normalizePrice(String raw) => raw.replaceAll('.', '').replaceAll(',', '');

  String _cleanItemName(String raw) {
    String name = raw.trim()
        .replaceAll(RegExp(r'^[Rr][Pp]\.?\s*'), '')
        .replaceAll(RegExp(r'^[-*|]+|[-*|]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name == name.toLowerCase() && name.isNotEmpty) {
      name = name.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
    }
    return name;
  }

  String _cleanText(String raw) => raw.replaceAll(RegExp(r'[^\w\s.,\-]'), '').trim();

  Future<void> _openMaps(String query) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _saveToHistory() {
    if (_receiptData == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Struk disimpan ke Riwayat ✅', style: GoogleFonts.poppins(fontSize: 12)),
      backgroundColor: AppColors.success, duration: const Duration(seconds: 2),
    ));
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HistoryScreen()), (r) => r.isFirst);
    });
  }

  void _goToSplit() {
    if (_receiptData == null) return;
    final items = _receiptData!.items.map((i) => {
      'name': i.name,
      'quantity': i.quantity,
      'unitPrice': i.unitPrice,
      'totalPrice': i.totalPrice,
      'checked': false,
    }).toList();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RoomShareScreen(items: items, storeName: _receiptData!.storeName, date: _receiptData!.date),
    ));
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(child: SingleChildScrollView(child: Column(children: [
            _buildCameraArea(),
            _buildActionButtons(),
            if (_isLoading) _buildLoadingState(),
            if (_errorMessage != null) _buildErrorState(),
            if (_receiptData != null && !_isLoading)
              FadeTransition(opacity: _fadeAnim, child: _buildReceiptResult()),
            const SizedBox(height: 100),
          ]))),
        ]),
      ),
      bottomNavigationBar: _receiptData != null && !_isLoading ? _buildBottomButtons() : null,
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(children: [
      GestureDetector(onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20)),
      const SizedBox(width: 12),
      Text('Scan Struk', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _buildCameraArea() => Container(
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    height: 220,
    decoration: BoxDecoration(
      color: AppColors.primaryDark.withOpacity(0.6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.15)),
    ),
    child: _imageFile != null
        ? ClipRRect(borderRadius: BorderRadius.circular(20),
            child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity))
        : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 70, height: 60, child: CustomPaint(painter: _ScanFramePainter())),
            const SizedBox(height: 12),
            Text('Arahkan ke struk belanja', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 6),
            Text('Pastikan struk terlihat jelas & tidak buram', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
          ])),
  );

  Widget _buildActionButtons() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Column(children: [
      _buildButton(label: 'Arahkan ke struk belanja', onTap: _pickFromCamera),
      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: _OrDivider()),
      _buildButton(label: 'Pilih dari Galeri', onTap: _pickFromGallery),
    ]),
  );

  Widget _buildButton({required String label, required VoidCallback onTap}) =>
    GestureDetector(onTap: onTap, child: Container(
      width: double.infinity, height: 52,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
    ));

  Widget _buildLoadingState() => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(children: [
      const CircularProgressIndicator(color: AppColors.primary),
      const SizedBox(height: 14),
      Text('Menganalisis struk...', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text('Mohon tunggu sebentar', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint)),
    ]),
  );

  Widget _buildErrorState() => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withOpacity(0.3))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.error),
      const SizedBox(width: 10),
      Expanded(child: Text(_errorMessage!, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error))),
      GestureDetector(onTap: _processImage,
          child: Text('Coba Lagi', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary))),
    ]),
  );

  Widget _buildReceiptResult() {
    final data = _receiptData!;
    final hasValid = data.items.any((i) => i.unitPrice > 0);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data.storeName, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              if (data.date.isNotEmpty)
                Text(data.date, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            if (data.locationQuery != null)
              GestureDetector(
                onTap: () => _openMaps(data.locationQuery!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.location_on_rounded, color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Text('Lihat di Maps', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary)),
                  ]),
                ),
              ),
          ]),
        ),
        if (!hasValid)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('Foto kurang jelas. Coba foto ulang dengan cahaya lebih terang.',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade700))),
              ]),
            ),
          ),
        const SizedBox(height: 16),
        Divider(color: AppColors.divider, height: 1, indent: 20, endIndent: 20),
        const SizedBox(height: 8),
        // ── Item list: nama + qty sesuai struk + harga, TANPA tombol +/- ──
        ...data.items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text('${item.quantity}x · ${_formatRupiah(item.unitPrice)} / pcs',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Text(_formatRupiah(item.totalPrice),
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ]),
        )),
        Divider(color: AppColors.divider, thickness: 1.5, indent: 20, endIndent: 20),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(_formatRupiah(data.total), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBottomButtons() => Container(
    padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
    decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3))]),
    child: Row(children: [
      Expanded(child: GestureDetector(onTap: _saveToHistory, child: Container(
        height: 50, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: Text('Simpan Pribadi', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      ))),
      const SizedBox(width: 12),
      Expanded(child: GestureDetector(onTap: _goToSplit, child: Container(
        height: 50, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: Text('Buat Split', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      ))),
    ]),
  );
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const corner = 16.0; const len = 20.0;
    canvas.drawLine(Offset(corner, 0), Offset(corner + len, 0), paint);
    canvas.drawLine(Offset(corner, 0), Offset(corner, len), paint);
    canvas.drawLine(Offset(size.width - corner - len, 0), Offset(size.width - corner, 0), paint);
    canvas.drawLine(Offset(size.width - corner, 0), Offset(size.width - corner, len), paint);
    canvas.drawLine(Offset(corner, size.height - len), Offset(corner, size.height), paint);
    canvas.drawLine(Offset(corner, size.height), Offset(corner + len, size.height), paint);
    canvas.drawLine(Offset(size.width - corner, size.height - len), Offset(size.width - corner, size.height), paint);
    canvas.drawLine(Offset(size.width - corner - len, size.height), Offset(size.width - corner, size.height), paint);
    canvas.drawLine(Offset(corner + 4, size.height / 2), Offset(size.width - corner - 4, size.height / 2),
        Paint()..color = Colors.white54..strokeWidth = 1.5);
  }
  @override bool shouldRepaint(_) => false;
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Divider(color: Colors.white.withOpacity(0.3), thickness: 1)),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('Atau', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70))),
    Expanded(child: Divider(color: Colors.white.withOpacity(0.3), thickness: 1)),
  ]);
}