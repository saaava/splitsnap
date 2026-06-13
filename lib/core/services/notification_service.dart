import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] ${message.notification?.title}');
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  static const _channelId = 'payment_reminder';
  static const _channelName = 'Pengingat Pembayaran';
  static const _channelDesc = 'Notifikasi pengingat split bill';

  bool _initialized = false;

  /// Panggil SEKALI di main(), TIDAK butuh user login.
  /// Setup permission, channel, local notification, & listener foreground.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
        playSound: true,
      );
      final androidImpl = _localNotif
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(androidChannel);
      }
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotifTapped,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Kalau token refresh sementara user sudah login, langsung re-save.
    _fcm.onTokenRefresh.listen((newToken) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await _writeToken(uid, newToken);
    });
  }

  /// Panggil SETIAP KALI user berhasil login (atau saat AuthGate mendeteksi
  /// user != null). Idempotent — aman dipanggil berkali-kali.
  Future<void> saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[FCM] saveToken dibatalkan: belum login');
      return;
    }

    final token = await _fcm.getToken();
    if (token == null) {
      debugPrint('[FCM] saveToken dibatalkan: token null');
      return;
    }

    await _writeToken(uid, token);
  }

  Future<void> _writeToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('fcm_tokens').doc(uid).set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[FCM] Token saved for uid=$uid');
  }

  /// Hapus token saat logout (opsional, biar gak kekirim notif ke device
  /// yang sudah logout).
  Future<void> clearToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('fcm_tokens').doc(uid).delete();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;

    _localNotif.show(
      notif.hashCode,
      notif.title,
      notif.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['roomCode'],
    );
  }

  void _onNotifTapped(NotificationResponse response) {
    debugPrint('[FCM] Notif tapped, roomCode: ${response.payload}');
  }
}