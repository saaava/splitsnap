import 'package:cloud_firestore/cloud_firestore.dart';

class RoomService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Simpan room baru ke Firestore
  static Future<void> createRoom({
    required String roomCode,
    required String storeName,
    required String date,
    required List<Map<String, dynamic>> items,
    required String createdBy, // uid user pembuat
  }) async {
    await _db.collection('rooms').doc(roomCode).set({
      'roomCode': roomCode,
      'storeName': storeName,
      'date': date,
      'items': items,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Ambil data room berdasarkan kode
  static Future<Map<String, dynamic>?> getRoom(String roomCode) async {
    final doc = await _db
        .collection('rooms')
        .doc(roomCode.toUpperCase().trim())
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }
}