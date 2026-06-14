import 'dart:convert';
import 'package:flutter/foundation.dart'; // ← untuk debugPrint
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ✅ BENAR — tanpa /swagger
  static const String _baseUrl = 'https://splitsnapapi-production-e868.up.railway.app';
  static const String _tokenKey = 'jwt_token';
  static const String _userIdKey = 'user_id';
  static const String _displayNameKey = 'display_name';
  static const String _emailKey = 'user_email';
  static const String _photoUrlKey = 'photo_url';

  // ─── Token management ────────────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // ✅ Hanya 1 getToken — duplikat dihapus, print untuk debug
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    debugPrint('JWT TOKEN: $token');
    return token;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_photoUrlKey);
  }

  Future<void> saveUserInfo({
    required String userId,
    required String displayName,
    required String email,
    String? photoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_displayNameKey, displayName);
    await prefs.setString(_emailKey, email);
    if (photoUrl != null) await prefs.setString(_photoUrlKey, photoUrl);
  }

  Future<Map<String, String?>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString(_userIdKey),
      'displayName': prefs.getString(_displayNameKey),
      'email': prefs.getString(_emailKey),
      'photoUrl': prefs.getString(_photoUrlKey),
    };
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ─── HTTP helpers ─────────────────────────────────────────────────────────────

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      final msg = body['message'] as String? ?? 'Terjadi kesalahan';
      throw msg;
    }
    return body;
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    return _post('/auth/register', {
      'displayName': displayName,
      'email': email,
      'password': password,
    }, auth: false);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _post('/auth/login', {
      'email': email,
      'password': password,
    }, auth: false);

    await saveToken(res['tokenJwt'] as String);
    await saveUserInfo(
      userId: res['userId'] as String,
      displayName: res['displayName'] as String? ?? email.split('@').first,
      email: res['email'] as String,
      photoUrl: res['photoUrl'] as String?,
    );
    return res;
  }

  Future<void> logout() async {
    try {
      await _post('/auth/logout', {});
    } catch (_) {}
    await clearToken();
  }

  Future<Map<String, dynamic>> getProfile() async {
    return _get('/auth/profile');
  }

  // ─── SPLIT / ROOM ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createRoom({
    required String roomCode,
    required String storeName,
    required String date,
    required List<Map<String, dynamic>> items,
    required String createdBy,
    required String createdByName,
  }) async {
    return _post('/split/create-room', {
      'roomCode': roomCode,
      'storeName': storeName,
      'date': date,
      'items': items,
      'createdBy': createdBy,
      'createdByName': createdByName,
    });
  }

  Future<Map<String, dynamic>> joinRoom({
    required String roomCode,
    required String uid,
    required String displayName,
  }) async {
    return _post('/split/join-room', {
      'roomCode': roomCode,
      'uid': uid,
      'displayName': displayName,
    });
  }

  Future<Map<String, dynamic>> getRoom(String roomCode) async {
    return _get('/split/rooms/$roomCode');
  }

  Future<Map<String, dynamic>> selectItems({
    required String roomCode,
    required String uid,
    required List<Map<String, dynamic>> selectedItems,
  }) async {
    return _put('/split/rooms/$roomCode/select-items', {
      'uid': uid,
      'selectedItems': selectedItems,
    });
  }

  Future<Map<String, dynamic>> confirmPayment({
    required String roomCode,
    required String uid,
  }) async {
    return _put('/split/rooms/$roomCode/confirm-payment', {'uid': uid});
  }

  Future<Map<String, dynamic>> markPaid({
    required String roomCode,
    required String uid,
  }) async {
    return _put('/split/rooms/$roomCode/mark-paid', {'uid': uid});
  }

  // ─── TRANSACTIONS ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getTransactions({
    String? type,
    String? filter,
    int limit = 20,
    int offset = 0,
  }) async {
    var path = '/transactions?limit=$limit&offset=$offset';
    if (type != null) path += '&type=$type';
    if (filter != null) path += '&filter=$filter';
    return _get(path);
  }

  Future<Map<String, dynamic>> getTransaction(String id) async {
    return _get('/transactions/$id');
  }

  Future<Map<String, dynamic>> createTransaction({
    required String type,
    required String name,
    required String date,
    required String people,
    required int amount,
    required String status,
    required String subtitle,
    required String detail,
    String? roomCode,
    List<Map<String, dynamic>> items = const [],
  }) async {
    return _post('/transactions', {
      'type': type,
      'name': name,
      'date': date,
      'people': people,
      'amount': amount,
      'status': status,
      'subtitle': subtitle,
      'detail': detail,
      'roomCode': roomCode,
      'items': items,
    });
  }

  Future<Map<String, dynamic>> deleteTransaction(String id) async {
    return _delete('/transactions/$id');
  }

  Future<Map<String, dynamic>> getChartData({String period = 'week'}) async {
    return _get('/transactions/chart?period=$period');
  }

  // ─── WALLET ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getBalance() async {
    return _get('/wallet/balance');
  }

  Future<Map<String, dynamic>> topUp(int amount) async {
    return _post('/wallet/topup', {'amount': amount});
  }

  Future<Map<String, dynamic>> withdraw(int amount) async {
    return _post('/wallet/withdraw', {'amount': amount});
  }

  Future<Map<String, dynamic>> getWalletActivity({
    int limit = 20,
    int offset = 0,
  }) async {
    return _get('/wallet/activity?limit=$limit&offset=$offset');
  }

  // ─── NOTIFICATIONS ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendReminder({
    required String roomCode,
    required String storeName,
    required List<Map<String, dynamic>> bills,
  }) async {
    return _post('/notifications/send-reminder', {
      'roomCode': roomCode,
      'storeName': storeName,
      'bills': bills,
    });
  }

  Future<Map<String, dynamic>> registerFcmToken({
    required String uid,
    required String fcmToken,
  }) async {
    return _post('/notifications/register-token', {
      'uid': uid,
      'fcmToken': fcmToken,
    });
  }

  Future<Map<String, dynamic>> getNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    return _get('/notifications?limit=$limit&offset=$offset');
  }
}