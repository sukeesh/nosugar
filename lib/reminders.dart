import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'state.dart';

/// Nightly nudges. We schedule the next week as one-off notifications rather
/// than one repeating one, so tonight's can be skipped once the star is lit.
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _lines = [
    "Tonight's crystal is waiting. Hold to turn it into a star.",
    'One hold and your sky gets brighter.',
    'Was today sugar-free? Light your star.',
    'Your constellation is one star from longer.',
    'A quiet minute before bed: light tonight\'s star.',
    'Check in honestly. The sky only shines if it\'s real.',
    'Star waiting. Crystal dissolving. Your call.',
  ];

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('reminders init failed: $e');
    }
  }

  static Future<bool> requestPermission() async {
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(alert: true, sound: true, badge: false) ?? await android?.requestNotificationsPermission() ?? false;
    return granted;
  }

  static Future<void> reschedule(AppState s) async {
    await init();
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!s.remindersOn || !s.onboarded) return;
    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < 7; i++) {
      final when = tz.TZDateTime(tz.local, now.year, now.month, now.day + i, s.reminderHour, s.reminderMinute);
      if (when.isBefore(now)) continue;
      if (i == 0 && s.todayDone) continue;
      final day = when.day + when.month * 31;
      await _plugin.zonedSchedule(
        id: 100 + i,
        scheduledDate: when,
        title: i == 0 ? 'Star ${s.streak + 1} is waiting' : 'nosugar',
        body: _lines[day % _lines.length],
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(),
          android: AndroidNotificationDetails('nightly', 'Nightly check-in', importance: Importance.defaultImportance),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
