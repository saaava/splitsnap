import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoomService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Buat room baru (tanpa host di participants dulu)
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
      'reminderTriggered': false,
      'createdAt': FieldValue.serverTimestamp(),
      'participants': [],
      'bills': [],
    });
  }

  /// Tambahkan host ke participants setelah createRoom
  /// Dipanggil dari RoomShareScreen._saveRoomToFirestore()
  static Future<void> addHostToRoom({required String roomCode}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final hostName = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : user.email?.split('@').first ?? 'Host';
    final hostInitials = hostName
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    final ref = _db.collection('rooms').doc(roomCode);
    final doc = await ref.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final participants = List<Map<String, dynamic>>.from(
      (data['participants'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    // Jangan duplikat
    if (participants.any((p) => p['uid'] == uid)) return;

    await ref.update({
      'participants': FieldValue.arrayUnion([
        {
          'uid': uid,
          'name': hostName,
          'initials': hostInitials,
          'isPaid': true,
          'isHost': true,
          'selectedItems': [],
          'total': 0,
        }
      ]),
    });
  }

  /// Ambil data room sekali (one-time fetch)
  static Future<Map<String, dynamic>?> getRoom(String roomCode) async {
    final doc = await _db
        .collection('rooms')
        .doc(roomCode.toUpperCase().trim())
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// Stream realtime — dipakai RoomScreen
  static Stream<DocumentSnapshot> roomStream(String roomCode) {
    return _db.collection('rooms').doc(roomCode).snapshots();
  }

  /// Peserta join room
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

    // Jangan duplikat
    if (participants.any((p) => p['uid'] == uid)) return;

    final initials = displayName
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

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

  /// Update item yang dipilih peserta + total tagihan
  /// Dipanggil dari JoinRoomScreen._confirmSelection()
  /// Nama method: updateParticipantItems (sesuai yang dipanggil di JoinRoomScreen)
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
      0,
      (sum, item) => sum + (item['totalPrice'] as int? ?? 0),
    );

    final updated = participants.map((p) {
      if (p['uid'] == uid) {
        return {
          ...p,
          'selectedItems': selectedItems
              .map((item) => {
                    'name': item['name'],
                    'quantity': item['quantity'],
                    'unitPrice': item['unitPrice'],
                    'totalPrice': item['totalPrice'],
                  })
              .toList(),
          'total': total,
        };
      }
      return p;
    }).toList();

    await ref.update({'participants': updated});
  }

  /// Alias updateParticipantSelection — dipakai RoomService internal
  static Future<void> updateParticipantSelection({
    required String roomCode,
    required String uid,
    required List<Map<String, dynamic>> selectedItems,
    required int total,
  }) async {
    await updateParticipantItems(
      roomCode: roomCode,
      uid: uid,
      selectedItems: selectedItems,
    );
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
}