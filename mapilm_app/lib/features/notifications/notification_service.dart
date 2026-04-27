import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/network/dio_client.dart';
import 'notification_handler.dart';

// Top-level handler for background messages (must be outside any class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService._showLocalNotification(message);
}

class NotificationService {
  NotificationService._();
  static final _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'mapilm_messages';
  static const _channelName = 'رسائل Mapilm';
  static const _channelDesc = 'إشعارات الرسائل الجديدة';

  // Called once from main.dart
  Future<void> initialize({
    required DioClient dioClient,
    BuildContext? context,
  }) async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);

    // Init local notifications
    await _initLocalNotifications();

    // Request permission
    await _requestPermission();

    // Get and register FCM token
    await _registerToken(dioClient);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((msg) {
      if (context != null && context.mounted) {
        NotificationHandler.handleForeground(msg, context: context);
      } else {
        _showLocalNotification(msg);
      }
    });

    // Handle notification tap when app in background
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      NotificationHandler.navigate(msg.data);
    });

    // Handle notification tap when app was terminated
    final initialMsg = await _messaging.getInitialMessage();
    if (initialMsg != null) {
      // Slight delay so navigator is ready
      Future.delayed(const Duration(seconds: 1), () {
        NotificationHandler.navigate(initialMsg.data);
      });
    }

    // Token refresh
    _messaging.onTokenRefresh.listen((token) {
      _sendTokenToServer(dioClient, token);
    });
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          NotificationHandler.navigate(data);
        }
      },
    );

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      showBadge: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _registerToken(DioClient client) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _sendTokenToServer(client, token);
    }
  }

  Future<void> _sendTokenToServer(DioClient client, String token) async {
    try {
      await client.post('/users/fcm-token/', data: {'token': token});
    } catch (_) {}
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final plugin = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await plugin.show(
      message.hashCode,
      notification.title ?? 'Mapilm',
      notification.body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  }
}
