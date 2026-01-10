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
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      initializationSettings,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    await updateToken();
  }

  static Future<void> updateToken() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String? token = await _messaging.getToken();
      if (token != null) {
        // 프로젝트 구조에 맞게 'profiles' 컬렉션에 저장하도록 수정
        await FirebaseFirestore.instance.collection('profiles').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          // 알림 설정이 없으면 기본값으로 true 설정
          'notificationsEnabled': true,
        }, SetOptions(merge: true));
      }
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
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: android.smallIcon,
            priority: Priority.high,
            importance: Importance.max,
          ),
        ),
      );
    }
  }

  static Future<void> updateNotificationSetting(bool enabled) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 여기도 'profiles'로 수정
      await FirebaseFirestore.instance.collection('profiles').doc(user.uid).update({
        'notificationsEnabled': enabled,
      });
      if (!enabled) {
        await _messaging.deleteToken();
      } else {
        await updateToken();
      }
    }
  }
}
