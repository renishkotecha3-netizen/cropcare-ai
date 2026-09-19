import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'api.dart';

class NotificationService {
  final plugin = FlutterLocalNotificationsPlugin();
  bool ready = false;
  bool pushReady = false;
  String? deviceToken;
  String? pendingOpen;
  void Function(String?)? onOpen;
  StreamSubscription<String>? tokenSubscription;
  static const channel = AndroidNotificationChannel(
    'cropcare_alerts',
    'CropCare updates',
    description: 'Crop checks and nearby alerts',
    importance: Importance.high,
  );
  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'cropcare_alerts',
      'CropCare updates',
      channelDescription: 'Crop checks and nearby alerts',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  int idFor(String id) {
    var value = 0;
    for (final c in id.codeUnits) {
      value = (value * 31 + c) & 0x7fffffff;
    }
    return value;
  }

  void open(String? scanId) {
    if (onOpen == null) {
      pendingOpen = scanId ?? 'inbox';
    } else {
      onOpen!(scanId);
    }
  }

  Future<void> init() async {
    if (!supported) return;
    tzdata.initializeTimeZones();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => open(response.payload),
    );
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false)
      pendingOpen = launch?.notificationResponse?.payload ?? 'inbox';
    ready = true;
    if (const bool.fromEnvironment('ENABLE_PUSH')) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
          appId: String.fromEnvironment('FIREBASE_APP_ID'),
          messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
          projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
          iosBundleId: 'com.cropcare.cropcareAi',
        ),
      );
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n != null) {
          plugin.show(
            idFor(
              message.data['notification_id'] ??
                  message.messageId ??
                  'cropcare',
            ),
            n.title,
            n.body,
            details,
          );
        }
      });
      FirebaseMessaging.onMessageOpenedApp.listen((_) => open(null));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) pendingOpen = 'inbox';
      pushReady = true;
    }
  }

  Future<void> enable(Api api) async {
    if (!ready) {
      throw ApiException(
        'Phone notifications are unavailable. Your in-app reminders still work.',
      );
    }
    final allowed = await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final iosAllowed = await plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (allowed == false || iosAllowed == false)
      throw ApiException(
        'Notifications are disabled. You can enable them in your phone settings.',
      );
    if (pushReady) {
      await FirebaseMessaging.instance.requestPermission();
      deviceToken = await FirebaseMessaging.instance.getToken();
      if (deviceToken != null)
        await api.call('POST', 'devices/', {'token': deviceToken});
      await tokenSubscription?.cancel();
      tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
        token,
      ) async {
        deviceToken = token;
        if (api.token != null) {
          try {
            await api.call('POST', 'devices/', {'token': token});
          } catch (_) {
            /* Retry on next sign-in. */
          }
        }
      });
    }
    await sync(api);
  }

  Future<void> sync(Api api) async {
    if (!ready) return;
    final response = await api.call('GET', 'reminders/');
    final reminders = List<Map<String, dynamic>>.from(response['results']);
    final ids = reminders.map((e) => idFor(e['id'])).toSet();
    for (final scheduled in await plugin.pendingNotificationRequests()) {
      if (!ids.contains(scheduled.id)) await plugin.cancel(scheduled.id);
    }
    for (final item in reminders) {
      final due = DateTime.now().toUtc().add(const Duration(minutes: 1));
      if (!due.isAfter(DateTime.now().toUtc())) continue;
      await plugin.zonedSchedule(
        idFor(item['id']),
        'How is your plant now?',
        'Your seven-day crop check is due. Add a new leaf photo and record your progress.',
        tz.TZDateTime.from(due, tz.UTC),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: item['id'],
      );
    }
  }

  Future<void> clear() async {
    await tokenSubscription?.cancel();
    tokenSubscription = null;
    if (ready) await plugin.cancelAll();
    if (pushReady) await FirebaseMessaging.instance.deleteToken();
    deviceToken = null;
    pendingOpen = null;
  }
}
