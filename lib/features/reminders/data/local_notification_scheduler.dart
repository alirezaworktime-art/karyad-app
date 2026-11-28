import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../application/reminder_planner.dart';

/// Schedules reminders as Android notifications.
///
/// Uses inexact alarms: a reminder may come a few minutes late, but the app
/// needs no "exact alarm" permission and survives battery savers. Scheduled
/// notifications are restored after a reboot by the plugin's boot receiver.
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _askedPermission = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'یادآورها',
      channelDescription: 'سرویس، بیمه، معاینه‌ی فنی و کیلومترشمار',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF4B2E83),
    ),
  );

  static Future<LocalNotificationScheduler> create() async {
    tz_data.initializeTimeZones();
    // Iran has had no daylight saving since 2022; the instant we schedule
    // comes from the device clock either way.
    tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    return LocalNotificationScheduler._(plugin);
  }

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async {
    await _plugin.cancelAll();
    if (reminders.isEmpty) return;
    await _askPermissionOnce();
    for (var i = 0; i < reminders.length; i++) {
      final r = reminders[i];
      await _plugin.zonedSchedule(
        id: i,
        title: r.title,
        body: r.body,
        scheduledDate: tz.TZDateTime.from(r.when, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: r.key,
      );
    }
  }

  /// Android 13+ asks the user; earlier versions allow it by default.
  Future<void> _askPermissionOnce() async {
    if (_askedPermission) return;
    _askedPermission = true;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }
}
