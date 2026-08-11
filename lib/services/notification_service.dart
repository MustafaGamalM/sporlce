import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sporcle/app_colors.dart';
import 'package:sporcle/services/call_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await CallService.showIncomingCall();
}

class NotificationServices {
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'basicChannelId';
  static const String _channelName = 'Sporcle alerts';
  static const String _channelDescription =
      'Game room invitations, score updates, and activity alerts';
  static const String _notificationIcon = 'ic_stat_sporcle_notification';
  static const Color _darkNotificationColor = AppColors.danger;

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.max,
  );

  @pragma('vm:entry-point')
  static Future<void> onReceiveNotificationResponse(
    NotificationResponse notificationResponse,
  ) async {
    final Map<String, dynamic> payload = _decodePayload(
      notificationResponse.payload,
    );

    debugPrint('Local notification clicked');
    debugPrint(payload.toString());
    debugPrint('Action: ${notificationResponse.actionId ?? 'default_tap'}');

    handleLocalNotificationClick(payload);
  }

  static Future<void> initNotification() async {
    await messaging.requestPermission();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings(_notificationIcon),
      iOS: DarwinInitializationSettings(),
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: onReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onReceiveNotificationResponse,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleFirebaseNotificationClick(message);
    });

    final RemoteMessage? initialMessage = await messaging.getInitialMessage();

    if (initialMessage != null) {
      handleFirebaseNotificationClick(initialMessage);
    }

    debugPrint('======');
    debugPrint(await getUserToken());
    debugPrint('======');
  }

  static Future<String> getUserToken() async {
    return await messaging.getToken() ?? '';
  }

  static void handleFirebaseNotificationClick(RemoteMessage message) {
    debugPrint('Firebase notification clicked');
    debugPrint(message.data.toString());

    handleLocalNotificationClick(_payloadFromMessage(message));
  }

  static void handleLocalNotificationClick(Map<String, dynamic> payload) {
    debugPrint('Notification payload ready for navigation');
    debugPrint(payload.toString());
  }

  static void handleForegroundMessage() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await showBasicNotification(message);
    });
  }

  static Future<void> showBasicNotification(RemoteMessage message) async {
    await CallService.showIncomingCall();

    final String title = _notificationTitle(message);
    final String body = _notificationBody(message);
    final String payload = jsonEncode(_payloadFromMessage(message));

    final NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        icon: _notificationIcon,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: _darkNotificationColor,
        colorized: true,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,

        autoCancel: true,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        ticker: 'New Sporcle message',
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Tap to open',
        ),
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'open_message',
            'Open',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final int notificationId =
        message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await flutterLocalNotificationsPlugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  static String _notificationTitle(RemoteMessage message) {
    return message.notification?.title ??
        message.data['title']?.toString() ??
        'Sporcle';
  }

  static String _notificationBody(RemoteMessage message) {
    return message.notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        'You have a new message.';
  }

  static Map<String, dynamic> _payloadFromMessage(RemoteMessage message) {
    return <String, dynamic>{
      'messageId': message.messageId,
      'title': _notificationTitle(message),
      'body': _notificationBody(message),
      'data': message.data,
    };
  }

  static Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      return <String, dynamic>{'raw': payload};
    }

    return <String, dynamic>{'raw': payload};
  }
}
