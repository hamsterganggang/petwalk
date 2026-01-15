import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'petwalk_notifications',
    '산책 및 소셜 알림',
    description: '좋아요, 팔로우 등 소셜 활동 알림을 수신합니다.',
    importance: Importance.max,
    playSound: true,
  );

  static Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(const InitializationSettings(android: initializationSettingsAndroid));

    FirebaseMessaging.onMessage.listen((RemoteMessage message) => _showLocalNotification(message));

    // 앱 시작 시 로그인 상태라면 토큰 갱신
    await updateToken();
  }

  /// FCM 토큰 업데이트 (중복 등록 방지 로직 추가)
  static Future<void> updateToken() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String? token = await _messaging.getToken();
      if (token == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('profiles').doc(user.uid).get();
      final isEnabled = userDoc.data()?['notificationsEnabled'] ?? true;

      if (!isEnabled) return;

      // [핵심] 동일한 토큰을 가진 다른 유저가 있다면 토큰을 삭제 (계정 전환 시 꼬임 방지)
      final otherUsersWithSameToken = await FirebaseFirestore.instance
          .collection('profiles')
          .where('fcmToken', isEqualTo: token)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in otherUsersWithSameToken.docs) {
        if (doc.id != user.uid) {
          batch.update(doc.reference, {'fcmToken': FieldValue.delete()});
        }
      }
      
      // 현재 유저에게 토큰 할당
      batch.set(FirebaseFirestore.instance.collection('profiles').doc(user.uid), {
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      print('FCM 토큰이 현재 계정(${user.uid})으로 독점 등록되었습니다.');
    } catch (e) {
      print('FCM 토큰 업데이트 실패: $e');
    }
  }

  /// FCM 토큰 제거 (로그아웃 시 호출)
  static Future<void> clearToken() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. 서버에서 토큰 삭제
      await FirebaseFirestore.instance.collection('profiles').doc(user.uid).update({
        'fcmToken': FieldValue.delete(),
      });
      
      // 2. 기기에서 토큰 무효화 (다음 로그인 시 무조건 새 토큰 생성)
      await _messaging.deleteToken();
      print('로그아웃: 서버 및 기기에서 FCM 토큰이 제거되었습니다.');
    } catch (e) {
      print('FCM 토큰 제거 실패: $e');
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id, _channel.name,
            channelDescription: _channel.description,
            icon: android.smallIcon ?? '@mipmap/ic_launcher',
            priority: Priority.high,
            importance: Importance.max,
          ),
        ),
      );
    }
  }

  static Future<void> updateNotificationSetting(bool enabled) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('profiles').doc(user.uid).update({
        'notificationsEnabled': enabled,
      });

      if (!enabled) {
        await clearToken();
      } else {
        // 활성화 시 토큰 다시 생성하여 등록
        await updateToken();
      }
    } catch (e) {
      print('알림 설정 업데이트 실패: $e');
    }
  }
}
