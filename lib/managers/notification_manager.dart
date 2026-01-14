import 'dart:async';
import 'package:flutter/material.dart';
// ▼▼▼ REQUIRED IMPORTS ▼▼▼
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. TOP-LEVEL FUNCTION FOR BACKGROUND ACTIONS
// This must be outside the class to handle clicks when the app is closed.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle background actions here (e.g., logging)
  debugPrint('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with payload: ${notificationResponse.payload}');
}

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // Handle foreground taps
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification tapped: ${response.actionId}");
        // You can add logic here to navigate to specific pages
      },
      // Handle background taps
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // === SCHEDULED DAILY NOTIFICATION ===
  Future<void> scheduleDailyNotification(TimeOfDay time) async {
    await cancelNotifications();

    final tz.TZDateTime scheduledDate = _nextInstanceOfTime(time);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Daily Truth Awaits',
      'Discover your quote of the day.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_quote_channel',
          'Daily Quotes',
          channelDescription: 'Daily notification for the quote of the day',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // === NEW: TEST NOTIFICATION WITH REAL DATA & BUTTONS ===
  Future<void> showTestNotification() async {
    try {
      // 1. Fetch the Actual Daily Quote (Logic matches Home Page)
      final supabase = Supabase.instance.client;
      final countResponse = await supabase.from('quotes').count();

      String title = "QuoteVault";
      String body = "Discover wisdom.";

      if (countResponse > 0) {
        final now = DateTime.now();
        final diff = now.difference(DateTime(now.year, 1, 1, 0, 0));
        final dayOfYear = diff.inDays;
        final dailyIndex = dayOfYear % countResponse;

        final data = await supabase
            .from('quotes')
            .select()
            .range(dailyIndex, dailyIndex)
            .maybeSingle();

        if (data != null) {
          title = "Quote of the Day";
          body = '"${data['content']}"\n- ${data['author']}';
        }
      }

      // 2. Create Buttons (Actions)
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'daily_quote_channel',
        'Daily Quotes',
        channelDescription: 'Daily notification for the quote of the day',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''), // Allows long text
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
              'open_id',
              'Open',
              showsUserInterface: true // Opens the app
          ),
          AndroidNotificationAction(
            'like_id',
            'Like',
            showsUserInterface: true, // Opens app (Background logic is complex)
            cancelNotification: false,
          ),
        ],
      );

      const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

      // 3. Show Notification
      await flutterLocalNotificationsPlugin.show(
        999, // Test ID
        title,
        body,
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint("Error showing test notification: $e");
    }
  }

  Future<void> cancelNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}