import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the gentle daily reading reminder. Fully offline (local
/// notifications); FCM push is a separate P3 enhancement.
///
/// Platform setup still required for production: Android needs the
/// `flutter_local_notifications` receiver (added by the plugin) and a
/// notification icon; iOS needs the notification permission prompt (handled
/// below) and the default AppDelegate plugin registration (from `flutter create`).
class NotificationService {
  NotificationService();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'daily_reminder';
  static const _notificationId = 1001;

  Future<void> _ensureReady() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
          tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      // Fall back to UTC if the device zone can't be resolved.
    }
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: init);
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await _ensureReady();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    return true;
  }

  Future<void> scheduleDaily(int hour, int minute) async {
    await _ensureReady();
    await _plugin.cancel(id: _notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Saat teduh menanti 🌿',
      body: 'Luangkan waktu sejenak untuk membaca hari ini.',
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Pengingat harian',
          channelDescription: 'Pengingat lembut untuk membaca tiap hari',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  Future<void> cancel() async {
    await _ensureReady();
    await _plugin.cancel(id: _notificationId);
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());
