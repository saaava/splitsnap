import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:splitsnap/core/theme/app_theme.dart';
import 'package:splitsnap/features/split/screens/create_room_screen.dart';
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
  final String? locationQuery; // untuk buka gmaps

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
    // On Android 13+ READ_MEDIA_IMAGES; on older READ_EXTERNAL_STORAGE
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
      imageQuality: 85,
      maxWidth: 1600,
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
      imageQuality: 85,
      maxWidth: 1600,
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

  // ── OCR via Claude API ───────────────────────────────────────────────────

  Future<void> _processImage() async {
    if (_imageFile == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final ext = _imageFile!.path.split('.').last.toLowerCase();
      final mediaType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final response = await _callClaudeVision(base64Image, mediaType);
      final parsed = _parseClaudeResponse(response);

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

  Future<Map<String, dynamic>> _callClaudeVision(
      String base64Image, String mediaType) async {
    // NOTE: API key injected by Anthropic proxy — no hardcoded key needed
    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    final httpClient = HttpClient();
    final request = await httpClient.postUrl(uri);

    request.headers.set('content-type', 'application/json');
    // anthropic-version header required
    request.headers.set('anthropic-version', '2023-06-01');

    final body = jsonEncode({
      'model': 'claude-opus-4-6',
      'max_tokens': 1024,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Image,
              },
            },
            {
              'type': 'text',
              'text': '''Kamu adalah parser struk belanja. Analisis gambar struk ini dan kembalikan JSON ONLY (tanpa teks lain, tanpa markdown).

Format JSON:
{
  "storeName": "Nama toko",
  "date": "DD Bulan YYYY",
  "locationQuery": "nama toko alamat kota untuk google maps search",
  "items": [
    {"name": "Nama produk", "quantity": 1, "unitPrice": 9000}
  ]
}

Aturan:
- unitPrice adalah harga SATUAN (bukan total)
- Jika quantity tidak jelas, isi 1
- locationQuery: kombinasi nama toko + alamat jika ada di struk, untuk pencarian Google Maps
- Kembalikan HANYA JSON, tidak ada penjelasan'''
            }
          ],
        }
      ],
    });

    request.write(body);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    httpClient.close();

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}: $responseBody');
    }

    return jsonDecode(responseBody) as Map<String, dynamic>;
  }

  ReceiptData _parseClaudeResponse(Map<String, dynamic> apiResponse) {
    final content = apiResponse['content'] as List;
    final text = (content.first as Map)['text'] as String;

    // Bersihkan markdown fence jika ada
    String cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceAll(RegExp(r'```json|```'), '').trim();
    }

    final json = jsonDecode(cleaned) as Map<String, dynamic>;

    final itemsRaw = json['items'] as List? ?? [];
    final items = itemsRaw.map((e) {
      final m = e as Map<String, dynamic>;
      return ReceiptItem(
        name: m['name']?.toString() ?? '-',
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (m['unitPrice'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    return ReceiptData(
      storeName: json['storeName']?.toString() ?? 'Toko',
      date: json['date']?.toString() ?? '',
      items: items,
      locationQuery: json['locationQuery']?.toString(),
    );
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
    // TODO: persist via Firestore/SharedPreferences
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
              'checked': false,
            })
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateRoomScreen(
          items: items,
          storeName: _receiptData!.storeName,
        ),
      ),
    );
  }

  // ── Format helpers ──────────────────────────────────────────────────────

  String _formatRupiah(int amount) {
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
            filled: false,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: _OrDivider(),
          ),
          _buildButton(
            label: 'Pilih dari Galeri',
            onTap: _pickFromGallery,
            filled: false,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : AppColors.primary,
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
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
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
                // Maps button
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

          const SizedBox(height: 16),
          Divider(color: AppColors.divider, height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 8),

          // Item list with +/- controls
          ...data.items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return _buildItemRow(item, i);
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

  Widget _buildItemRow(ReceiptItem item, int index) {
    // Max quantity berdasarkan parsing awal (simpan ke originalQty tidak perlu karena kita batasi via slider)
    // Di sini kita pakai batas wajar: 1..99 tapi biasanya 1..10
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
          // Qty stepper
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
            width: 72,
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

    // Top-left
    canvas.drawLine(Offset(corner, 0), Offset(corner + len, 0), paint);
    canvas.drawLine(Offset(corner, 0), Offset(corner, len), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - corner - len, 0), Offset(size.width - corner, 0), paint);
    canvas.drawLine(Offset(size.width - corner, 0), Offset(size.width - corner, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(corner, size.height - len), Offset(corner, size.height), paint);
    canvas.drawLine(Offset(corner, size.height), Offset(corner + len, size.height), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - corner, size.height - len), Offset(size.width - corner, size.height), paint);
    canvas.drawLine(Offset(size.width - corner - len, size.height), Offset(size.width - corner, size.height), paint);

    // Center line
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