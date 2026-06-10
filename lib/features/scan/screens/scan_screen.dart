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

// ─── Model ─────────────────────────────────────────────────────────────────

class ReceiptItem {
  final String name;
  int quantity;
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

// ─── Main Screen ────────────────────────────────────────────────────────────

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
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Permission helpers ──────────────────────────────────────────────────

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showSettingsDialog('Kamera', 'Izin kamera diperlukan untuk scan struk.');
      }
      return false;
    }
    return status.isGranted;
  }

  Future<bool> _requestGalleryPermission() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.photos.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }
    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showSettingsDialog('Galeri', 'Izin galeri diperlukan untuk memilih foto struk.');
      }
      return false;
    }
    return status.isGranted;
  }

  void _showSettingsDialog(String type, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Izin $type Diperlukan',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Buka Pengaturan', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Image picking ────────────────────────────────────────────────────────

  Future<void> _pickFromCamera() async {
    final granted = await _requestCameraPermission();
    if (!granted) return;
    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 2000,
    );
    if (xfile != null) {
      setState(() {
        _imageFile = File(xfile.path);
        _receiptData = null;
        _errorMessage = null;
      });
      await _processImage();
    }
  }

  Future<void> _pickFromGallery() async {
    final granted = await _requestGalleryPermission();
    if (!granted) return;
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2000,
    );
    if (xfile != null) {
      setState(() {
        _imageFile = File(xfile.path);
        _receiptData = null;
        _errorMessage = null;
      });
      await _processImage();
    }
  }

  // ── OCR Processing ───────────────────────────────────────────────────────

  Future<void> _processImage() async {
    if (_imageFile == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final inputImage = InputImage.fromFile(_imageFile!);
      final textRecognizer = TextRecognizer();
      final recognized = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final parsed = _parseReceiptText(recognized.text);

      setState(() {
        _receiptData = parsed;
        _isLoading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memproses struk: ${e.toString()}';
      });
    }
  }

  // ── ROBUST MULTI-FORMAT RECEIPT PARSER ──────────────────────────────────
  //
  // Handles 3 common Indonesian receipt formats:
  //
  // FORMAT A (Minimarket / Alfamart / Indomaret style):
  //   NAMA BARANG              Rp 36.000
  //
  // FORMAT B (Two-line style):
  //   Nama Barang
  //   1 x 36,000               Rp 36.000
  //
  // FORMAT C (BreadTalk / Cafe style - numbered):
  //   1  Bread Butter Pudding     11,500
  //   1  Cream Brulle             14,000
  //
  ReceiptData _parseReceiptText(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // ── 1. Extract store name ──────────────────────────────────────────────
    String storeName = _extractStoreName(lines);

    // ── 2. Extract date ────────────────────────────────────────────────────
    String date = _extractDate(lines);

    // ── 3. Parse items ─────────────────────────────────────────────────────
    final items = _extractItems(lines);

    return ReceiptData(
      storeName: storeName,
      date: date,
      items: items.isEmpty
          ? [ReceiptItem(name: 'Item tidak terdeteksi - coba foto lebih jelas', quantity: 1, unitPrice: 0)]
          : items,
      locationQuery: storeName != 'Toko' ? storeName : null,
    );
  }

  String _extractStoreName(List<String> lines) {
    // Skip lines that look like dates/times/numbers at the top
    final datePattern = RegExp(r'^\d{4}[-/]\d{2}[-/]\d{2}');
    final timePattern = RegExp(r'^\d{2}:\d{2}');
    final numberOnlyPattern = RegExp(r'^\d+$');

    for (final line in lines.take(8)) {
      if (datePattern.hasMatch(line)) continue;
      if (timePattern.hasMatch(line)) continue;
      if (numberOnlyPattern.hasMatch(line)) continue;
      if (line.length < 3) continue;
      // Skip lines that look like addresses (contain "Jl.", "No.", etc.)
      if (RegExp(r'^(Jl|Jalan|No\.|Jl\.)', caseSensitive: false).hasMatch(line)) continue;
      // Skip pure number lines
      if (RegExp(r'^[\d\s.,]+$').hasMatch(line)) continue;
      // Good candidate: has letters and reasonable length
      if (RegExp(r'[a-zA-Z]').hasMatch(line) && line.length >= 3) {
        return _cleanText(line);
      }
    }
    return 'Toko';
  }

  String _extractDate(List<String> lines) {
    // Formats: 2023-08-02, 02/08/2023, 10 May 19, 23-08-02
    final patterns = [
      RegExp(r'\d{4}[-/]\d{1,2}[-/]\d{1,2}'),
      RegExp(r'\d{1,2}[-/]\d{1,2}[-/]\d{2,4}'),
      RegExp(r'\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{2,4}', caseSensitive: false),
    ];
    for (final line in lines) {
      for (final pattern in patterns) {
        final match = pattern.firstMatch(line);
        if (match != null) return match.group(0)!;
      }
    }
    return '';
  }

  List<ReceiptItem> _extractItems(List<String> lines) {
    final items = <ReceiptItem>[];

    // Keywords to skip entirely — covers payment/footer/summary lines
    final skipKeywords = RegExp(
      r'\b(total|tunai|kembali|kembal|ppn|pajak|tax|subtotal|sub\s*total|'
      r'cash|change|kembalian|uang kembali|bayar|bayaran|pembayaran|payment|'
      r'debit|kredit|credit|bca|mandiri|bri|bni|dana|ovo|gopay|shopeepay|'
      r'npwp|kasir|cashier|terima kasih|thank you|closed|open|'
      r'receipt|struk|invoice|nota|grand total|'
      r'service charge|service fee|tax amount|'
      r'harga total|jumlah|diskon|discount|promo|voucher|'
      r'ongkos|ongkir|delivery|member|poin|point|'
      r'tgl|tanggal|jam|waktu|no\s*struk|no\s*nota|no\s*faktur|'
      r'item qty|qty item|total qty|total item|total pcs|pcs total)\b',
      caseSensitive: false,
    );

    // Price regex: matches 1.000 / 1,000 / 11500 / 11.500
    final priceRegex = RegExp(r'\b(\d{1,3}(?:[.,]\d{3})+|\d{4,7})\b');

    // ── Detect format ────────────────────────────────────────────────────
    // Count lines that look like "1  ItemName  price" → Format C
    // Count lines where next line has qty×price → Format B
    // Otherwise Format A

    // Try FORMAT C first: "QTY  Name  Price" on same line
    // Pattern: starts with 1-2 digits, then text, then price
    final formatCPattern = RegExp(r'^(\d{1,2})\s+([A-Za-z][A-Za-z\s/\-]+?)\s+([\d.,]{4,})$');
    int formatCMatches = 0;
    for (final line in lines) {
      if (formatCPattern.hasMatch(line)) formatCMatches++;
    }

    if (formatCMatches >= 2) {
      // Format C: "1  Bread Butter Pudding  11,500"
      return _parseFormatC(lines, skipKeywords, priceRegex);
    }

    // Try FORMAT B: item name on one line, qty+price on next
    return _parseFormatAB(lines, skipKeywords, priceRegex);
  }

  // FORMAT C: BreadTalk style - "QTY Name Price" on same line
  List<ReceiptItem> _parseFormatC(
      List<String> lines, RegExp skipKeywords, RegExp priceRegex) {
    final items = <ReceiptItem>[];
    // Pattern: optional leading number, name, trailing price
    // e.g. "1  Bread Butter Pudding    11,500"
    //      "1  Bank Of Chocolat         7,500"
    final linePattern = RegExp(r'^(\d{1,2})\s+(.+?)\s+([\d.,]{4,})\s*$');

    for (final line in lines) {
      if (skipKeywords.hasMatch(line.toLowerCase())) continue;

      final match = linePattern.firstMatch(line);
      if (match == null) continue;

      final qty = int.tryParse(match.group(1)!) ?? 1;
      final rawName = match.group(2)!.trim();
      final priceStr = _normalizePrice(match.group(3)!);
      final price = int.tryParse(priceStr) ?? 0;

      if (price < 100 || price > 10000000) continue;
      final name = _cleanItemName(rawName);
      if (name.length < 2) continue;

      // Unit price = total / qty
      final unitPrice = qty > 0 ? price ~/ qty : price;
      items.add(ReceiptItem(name: name, quantity: qty, unitPrice: unitPrice));
    }
    return items;
  }

  // FORMAT A & B: Handles both single-line and two-line receipt formats
  List<ReceiptItem> _parseFormatAB(
      List<String> lines, RegExp skipKeywords, RegExp priceRegex) {
    final items = <ReceiptItem>[];

    // Identify "footer" zone: stop parsing when we hit summary/payment lines
    int footerStart = lines.length;
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].toLowerCase().trim();
      // Any line that is purely a total/subtotal/payment marker
      if (RegExp(
        r'^(subtotal|sub total|sub-total|total qty|total item|total pcs|'
        r'grand total|total\s*:?\s*[\d.,]+|tunai|kembali|kembalian|payment|'
        r'terima kasih|thank you)',
      ).hasMatch(l)) {
        footerStart = i;
        break;
      }
    }

    int i = 0;
    while (i < footerStart) {
      final line = lines[i];
      final lineLower = line.toLowerCase();

      // Skip non-item lines
      if (skipKeywords.hasMatch(lineLower) ||
          line.length < 2 ||
          RegExp(r'^[-=*]+$').hasMatch(line)) {
        i++;
        continue;
      }

      // ── Pattern: numbered item like "1. Indomie Goreng" or "2. Fruit Tea Apple"
      final numberedItemPattern = RegExp(r'^\d+\.\s+(.+)$');
      final numberedMatch = numberedItemPattern.firstMatch(line);

      if (numberedMatch != null) {
        // Item name is on this line, price/qty detail on next line
        final rawName = numberedMatch.group(1)!.trim();
        String name = _cleanItemName(rawName);

        // Look ahead for qty×price line
        int qty = 1;
        int unitPrice = 0;

        if (i + 1 < footerStart) {
          final nextLine = lines[i + 1];
          final qtyPriceInfo = _parseQtyPriceLine(nextLine);
          if (qtyPriceInfo != null) {
            qty = qtyPriceInfo['qty'] as int;
            unitPrice = qtyPriceInfo['unitPrice'] as int;
            i += 2; // consume both lines
          } else {
            // Maybe price is inline (Format A with number prefix)
            final prices = priceRegex.allMatches(line).toList();
            if (prices.isNotEmpty) {
              final p = int.tryParse(_normalizePrice(prices.last.group(0)!)) ?? 0;
              if (p >= 100 && p <= 10000000) unitPrice = p;
            }
            i++;
          }
        } else {
          i++;
        }

        if (name.length >= 2 && unitPrice > 0) {
          items.add(ReceiptItem(name: name, quantity: qty, unitPrice: unitPrice));
        }
        continue;
      }

      // ── Pattern: "ItemName    Rp 36.000" on same line (Format A)
      final pricesInLine = priceRegex.allMatches(line).toList();
      if (pricesInLine.isNotEmpty) {
        final lastPriceMatch = pricesInLine.last;
        final price = int.tryParse(_normalizePrice(lastPriceMatch.group(0)!)) ?? 0;

        if (price >= 100 && price <= 10000000) {
          // Extract name: text before the price, remove "Rp", numbers
          String name = line.substring(0, lastPriceMatch.start).trim();
          name = name.replaceAll(RegExp(r'\b[Rr][Pp]\.?\s*'), '').trim();
          name = _cleanItemName(name);

          // Check for qty (e.g., "2 x" or "@2")
          int qty = 1;
          final qtyMatch = RegExp(r'\b(\d{1,2})\s*[xX@]\s*').firstMatch(name);
          if (qtyMatch != null) {
            qty = int.tryParse(qtyMatch.group(1)!) ?? 1;
            name = name.replaceFirst(qtyMatch.group(0)!, '').trim();
            name = _cleanItemName(name);
          }

          if (name.length >= 2 && !skipKeywords.hasMatch(name.toLowerCase())) {
            final unitPrice = qty > 1 ? price ~/ qty : price;
            items.add(ReceiptItem(name: name, quantity: qty, unitPrice: unitPrice));
          }
          i++;
          continue;
        }
      }

      // ── Pattern: line has no price but might be item name (Format B leading line)
      // Check if next line is a qty×price line
      if (i + 1 < footerStart) {
        final nextLine = lines[i + 1];
        final qtyPriceInfo = _parseQtyPriceLine(nextLine);

        if (qtyPriceInfo != null && !skipKeywords.hasMatch(lineLower)) {
          final rawName = line;
          // Must look like an item name: contains letters, reasonable length
          if (RegExp(r'[a-zA-Z]').hasMatch(rawName) &&
              rawName.length >= 3 &&
              !RegExp(r'^\d{4}').hasMatch(rawName)) {
            String name = _cleanItemName(rawName);
            if (name.length >= 2) {
              final qty = qtyPriceInfo['qty'] as int;
              final unitPrice = qtyPriceInfo['unitPrice'] as int;
              if (unitPrice > 0) {
                items.add(ReceiptItem(name: name, quantity: qty, unitPrice: unitPrice));
                i += 2;
                continue;
              }
            }
          }
        }
      }

      i++;
    }

    return items;
  }

  // Parse lines like:
  //   "1 lusin x 36,000   Rp 36.000"
  //   "1 500ml x 7,000    Rp 7.000"
  //   "1 x 27,000         Rp 27.000"
  //   "2x9.500            Rp 19.000"
  Map<String, int>? _parseQtyPriceLine(String line) {
    // Pattern 1: "qty [unit] x unitPrice [total]"
    final pattern1 = RegExp(
      r'^(\d{1,3})\s*(?:[a-zA-Z/]+\s+)?[xX@]\s*([\d.,]+)',
    );
    final m1 = pattern1.firstMatch(line);
    if (m1 != null) {
      final qty = int.tryParse(m1.group(1)!) ?? 1;
      final unitPriceStr = _normalizePrice(m1.group(2)!);
      final unitPrice = int.tryParse(unitPriceStr) ?? 0;
      if (unitPrice >= 100 && unitPrice <= 5000000) {
        return {'qty': qty, 'unitPrice': unitPrice};
      }
    }

    // Pattern 2: just a price on the line (for multiline receipts where
    // the previous line was item name)
    final priceOnly = RegExp(r'^[Rr][Pp]\.?\s*([\d.,]+)\s*$');
    final m2 = priceOnly.firstMatch(line.trim());
    if (m2 != null) {
      final price = int.tryParse(_normalizePrice(m2.group(1)!)) ?? 0;
      if (price >= 100 && price <= 10000000) {
        return {'qty': 1, 'unitPrice': price};
      }
    }

    return null;
  }

  // Normalize price string: "36.000" → "36000", "36,000" → "36000"
  String _normalizePrice(String raw) {
    // Indonesian: dots as thousands separator → remove dots
    // If comma present as decimal → remove comma too (we only care about integers)
    String clean = raw.replaceAll('.', '').replaceAll(',', '');
    return clean;
  }

  // Clean up item name
  String _cleanItemName(String raw) {
    // Remove leading/trailing numbers that could be line numbers
    String name = raw.trim();
    // Remove leading "Rp" 
    name = name.replaceAll(RegExp(r'^[Rr][Pp]\.?\s*'), '');
    // Remove trailing/leading dashes, asterisks, pipes
    name = name.replaceAll(RegExp(r'^[-*|]+|[-*|]+$'), '').trim();
    // Remove multiple spaces
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Capitalize first letter of each word if all lowercase
    if (name == name.toLowerCase() && name.isNotEmpty) {
      name = name.split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');
    }
    return name;
  }

  // Clean store name
  String _cleanText(String raw) {
    return raw.replaceAll(RegExp(r'[^\w\s.,\-]'), '').trim();
  }

  // ── Open Maps ───────────────────────────────────────────────────────────

  Future<void> _openMaps(String query) async {
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Tidak bisa membuka Maps', style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ── Save to history ──────────────────────────────────────────────────────

  void _saveToHistory() {
    if (_receiptData == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Struk disimpan ke Riwayat ✅',
        style: GoogleFonts.poppins(fontSize: 12),
      ),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 2),
    ));
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
          (route) => route.isFirst,
        );
      }
    });
  }

  // ── Navigate to split room ───────────────────────────────────────────────

  void _goToSplit() {
    if (_receiptData == null) return;
    final items = _receiptData!.items
        .map((i) => {
              'name': i.name,
              'quantity': i.quantity,
              'unitPrice': i.unitPrice,
              'totalPrice': i.totalPrice,
              'checked': true,
            })
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomShareScreen(
          items: items,
          storeName: _receiptData!.storeName,
          date: _receiptData!.date,
        ),
      ),
    );
  }

  // ── Format helpers ──────────────────────────────────────────────────────

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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCameraArea(),
                    _buildActionButtons(),
                    if (_isLoading) _buildLoadingState(),
                    if (_errorMessage != null) _buildErrorState(),
                    if (_receiptData != null && !_isLoading)
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: _buildReceiptResult(),
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _receiptData != null && !_isLoading
          ? _buildBottomButtons()
          : null,
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Scan Struk',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: _imageFile != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                _imageFile!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildScanFrame(),
                  const SizedBox(height: 12),
                  Text(
                    'Arahkan ke struk belanja',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pastikan struk terlihat jelas & tidak buram',
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildScanFrame() {
    return SizedBox(
      width: 70,
      height: 60,
      child: CustomPaint(painter: _ScanFramePainter()),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          _buildButton(
            label: 'Arahkan ke struk belanja',
            onTap: _pickFromCamera,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: _OrDivider(),
          ),
          _buildButton(
            label: 'Pilih dari Galeri',
            onTap: _pickFromGallery,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 14),
          Text(
            'Menganalisis struk...',
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Mohon tunggu sebentar',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error),
            ),
          ),
          GestureDetector(
            onTap: _processImage,
            child: Text(
              'Coba Lagi',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptResult() {
    final data = _receiptData!;
    final hasValidItems = data.items.any((i) => i.unitPrice > 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.storeName,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (data.date.isNotEmpty)
                        Text(
                          data.date,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_rounded,
                              color: AppColors.primary, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Lihat di Maps',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Warning if items not detected well
          if (!hasValidItems)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Foto kurang jelas. Coba foto ulang dengan cahaya lebih terang.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
          Divider(color: AppColors.divider, height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 8),

          // Item list
          ...data.items.asMap().entries.map((entry) {
            final item = entry.value;
            return _buildItemRow(item);
          }),

          Divider(color: AppColors.divider, thickness: 1.5, indent: 20, endIndent: 20),

          // Total
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _formatRupiah(data.total),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(ReceiptItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_formatRupiah(item.unitPrice)} / pcs',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _qtyButton(
                icon: Icons.remove,
                onTap: item.quantity > 1
                    ? () => setState(() => item.quantity--)
                    : null,
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _qtyButton(
                icon: Icons.add,
                onTap: () => setState(() => item.quantity++),
              ),
            ],
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              _formatRupiah(item.totalPrice),
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.primary.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          icon,
          size: 14,
          color: onTap != null ? AppColors.primary : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _saveToHistory,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Simpan Pribadi',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _goToSplit,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Buat Split',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const corner = 16.0;
    const len = 20.0;

    canvas.drawLine(Offset(corner, 0), Offset(corner + len, 0), paint);
    canvas.drawLine(Offset(corner, 0), Offset(corner, len), paint);
    canvas.drawLine(Offset(size.width - corner - len, 0), Offset(size.width - corner, 0), paint);
    canvas.drawLine(Offset(size.width - corner, 0), Offset(size.width - corner, len), paint);
    canvas.drawLine(Offset(corner, size.height - len), Offset(corner, size.height), paint);
    canvas.drawLine(Offset(corner, size.height), Offset(corner + len, size.height), paint);
    canvas.drawLine(Offset(size.width - corner, size.height - len), Offset(size.width - corner, size.height), paint);
    canvas.drawLine(Offset(size.width - corner - len, size.height), Offset(size.width - corner, size.height), paint);

    final linePaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(corner + 4, size.height / 2),
      Offset(size.width - corner - 4, size.height / 2),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.3), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Atau',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.3), thickness: 1)),
      ],
    );
  }
}