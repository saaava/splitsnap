import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoomService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Simpan room baru ke Firestore
  static Future<void> createRoom({
    required String roomCode,
    required String storeName,
    required String date,
    required List<Map<String, dynamic>> items,
    required String createdBy,
  }) async {
    await _db.collection('rooms').doc(roomCode).set({
      'roomCode': roomCode,
      'storeName': storeName,
      'date': date,
      'items': items,
      'createdBy': createdBy,
      'participants': [],
      'bills': [],
      'reminderTriggered': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Tambahkan host ke participants setelah createRoom
  static Future<void> addHostToRoom({required String roomCode}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _db.collection('rooms').doc(roomCode);
    final doc = await ref.get();
    if (!doc.exists) return;

    final displayName = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : user.email?.split('@').first ?? 'Host';

    final initials = displayName.isNotEmpty
        ? displayName
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    await ref.update({
      'participants': FieldValue.arrayUnion([
        {
          'uid': user.uid,
          'name': displayName,
          'initials': initials,
          'isPaid': false,
          'isHost': true,
          'selectedItems': [],
          'total': 0,
        }
      ]),
    });
  }

  /// Ambil data room berdasarkan kode (one-time)
  static Future<Map<String, dynamic>?> getRoom(String roomCode) async {
    final doc = await _db
        .collection('rooms')
        .doc(roomCode.toUpperCase().trim())
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// Stream realtime data room — dipakai RoomScreen biar auto-update
  static Stream<DocumentSnapshot> roomStream(String roomCode) {
    return _db.collection('rooms').doc(roomCode).snapshots();
  }

  /// Peserta join room: tambahkan dirinya ke array participants di Firestore
  static Future<void> joinRoom({
    required String roomCode,
    required String uid,
    required String displayName,
  }) async {
    final ref = _db.collection('rooms').doc(roomCode);

    final doc = await ref.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final participants = List<Map<String, dynamic>>.from(
      (data['participants'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    final alreadyJoined = participants.any((p) => p['uid'] == uid);
    if (alreadyJoined) return;

    final initials = displayName.isNotEmpty
        ? displayName
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    await ref.update({
      'participants': FieldValue.arrayUnion([
        {
          'uid': uid,
          'name': displayName,
          'initials': initials,
          'isPaid': false,
          'isHost': false,
          'selectedItems': [],
          'total': 0,
        }
      ]),
    });
  }

  /// Simpan item yang dipilih peserta ke Firestore (realtime ke host)
  static Future<void> updateParticipantItems({
    required String roomCode,
    required String uid,
    required List<Map<String, dynamic>> selectedItems,
  }) async {
    final ref = _db.collection('rooms').doc(roomCode);
    final doc = await ref.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final participants = List<Map<String, dynamic>>.from(
      (data['participants'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    final total = selectedItems.fold<int>(
        0, (sum, item) => sum + (item['totalPrice'] as int? ?? 0));

    final updated = participants.map((p) {
      if (p['uid'] == uid) {
        return {
          ...p,
          'selectedItems': selectedItems,
          'total': total,
        };
      }
      return p;
    }).toList();

    await ref.update({'participants': updated});
  }

  /// Mark peserta sebagai lunas
  static Future<void> markPaid({
    required String roomCode,
    required String uid,
  }) async {
    final ref = _db.collection('rooms').doc(roomCode);
    final doc = await ref.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final participants = List<Map<String, dynamic>>.from(
      (data['participants'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    final updated = participants.map((p) {
      if (p['uid'] == uid) return {...p, 'isPaid': true};
      return p;
    }).toList();

    await ref.update({'participants': updated});
  }

  /// Trigger pengingat → FcmService kirim langsung
  static Future<void> triggerPaymentReminder(String roomCode) async {
    await _db.collection('rooms').doc(roomCode).update({
      'reminderTriggered': true,
    });
  }
}