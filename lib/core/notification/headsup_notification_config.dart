import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HeadsUpNotificationConfig {
  static AndroidNotificationDetails createHeadsUpDetails({
    required String title,
    required String body,
  }) {
    return AndroidNotificationDetails(
      'activity_reminders',
      'Activity Reminders',
      channelDescription: 'Reminders for daily sleep activities',

      importance: Importance.max,
      priority: Priority.max,

      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,

      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([
        0,
        500,
        200,
        500,
        200,
        500,
        200,
        500,
        200,
        500,
      ]),

      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: false,
      channelShowBadge: true,
      onlyAlertOnce: false,
      autoCancel: false,
      ongoing: false,

      ticker: '🌙 Time for your snoozio activity!',

      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Snoozio Sleep Reminder',
        htmlFormatBigText: true,
        htmlFormatContentTitle: true,
      ),

      enableLights: true,
      ledColor: const Color(0xFF6C5CE7),
      ledOnMs: 1000,
      ledOffMs: 500,

      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'open_app',
          '✅ Open App',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          'mark_done',
          '✓ Mark Done',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],

      additionalFlags: Int32List.fromList([4]),
    );
  }

  static NotificationDetails createNotificationDetails({
    required String title,
    required String body,
  }) {
    return NotificationDetails(
      android: createHeadsUpDetails(title: title, body: body),
    );
  }
}
