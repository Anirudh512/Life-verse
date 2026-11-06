import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static bool get _supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> initialize() async {
    if (_initialized || !_supportedPlatform) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_supportedPlatform) return;
    await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'lifeverse_alerts',
          'LifeVerse Alerts',
          channelDescription:
              'Important alerts from your Twin Mind and Network',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    String channelId = 'lifeverse_schedule',
    String channelName = 'Time Capsules',
    String channelDescription = 'Notifications for when time capsules open',
    AndroidScheduleMode scheduleMode =
        AndroidScheduleMode.inexactAllowWhileIdle,
  }) async {
    if (!_supportedPlatform) return;
    await initialize();

    final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(
      scheduledTime,
      tz.local,
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzScheduledTime,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      payload: payload,
    );
  }

  static Future<void> syncGrowthGoalReminders(
    List<Map<String, dynamic>> goals,
  ) async {
    if (!_supportedPlatform) return;
    await initialize();
    const payloadPrefix = 'lifeverse_growth_goal:';
    final scheduledGoalIds = <int>{};
    final eligibleGoals =
        <
          ({
            int notificationId,
            String id,
            String title,
            DateTime scheduledTime,
          })
        >[];
    final now = DateTime.now();

    for (final goal in goals) {
      final id = goal['id']?.toString() ?? '';
      final reminder =
          goal['reminderEnabled'] == true ||
          goal['reminderEnabled'] == 1 ||
          goal['reminderEnabled'] == '1';
      final complete = goal['isComplete'] == true;
      final dueDate = DateTime.tryParse('${goal['dueDate'] ?? ''}');
      if (id.isEmpty || !reminder || complete || dueDate == null) continue;

      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      var reminderAt = dueDay
          .subtract(const Duration(days: 1))
          .add(const Duration(hours: 9));
      if (!reminderAt.isAfter(now)) {
        reminderAt = dueDay.add(const Duration(hours: 9));
      }
      if (!reminderAt.isAfter(now)) continue;
      final notificationId = _growthGoalNotificationId(id);
      scheduledGoalIds.add(notificationId);
      eligibleGoals.add((
        notificationId: notificationId,
        id: id,
        title: goal['title']?.toString() ?? 'Growth goal',
        scheduledTime: reminderAt,
      ));
    }

    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith(payloadPrefix) == true &&
          !scheduledGoalIds.contains(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }

    for (final goal in eligibleGoals) {
      try {
        await _plugin.cancel(id: goal.notificationId);
        await scheduleNotification(
          id: goal.notificationId,
          title: 'LifeVerse growth goal reminder',
          body:
              'Your goal “${goal.title}” is due soon. Take a moment to check your progress.',
          scheduledTime: goal.scheduledTime,
          payload: '$payloadPrefix${goal.id}',
          channelId: 'lifeverse_goal_reminders',
          channelName: 'Growth Goal Reminders',
          channelDescription:
              'Optional reminders for your personal LifeVerse goals',
        );
      } catch (error) {
        debugPrint('Could not schedule reminder for goal ${goal.id}: $error');
      }
    }
  }

  static int _growthGoalNotificationId(String goalId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in goalId.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    return 0x40000000 | (hash & 0x3fffffff);
  }

  static Future<void> cancelGrowthGoalReminder(String goalId) async {
    if (!_supportedPlatform) return;
    await initialize();
    await _plugin.cancel(id: _growthGoalNotificationId(goalId));
  }
}
