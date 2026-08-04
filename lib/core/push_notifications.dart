import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Must be a top-level function (not a class method/closure) -- FCM invokes
// this in a separate background isolate when a data message arrives while
// the app isn't in the foreground.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM message: ${message.messageId}');
}

/// Every device subscribes to this topic, so notifications can be sent to
/// all users straight from the Firebase console's Cloud Messaging screen
/// (target: topic "all_users") with zero backend work. Per-user targeted
/// notifications (e.g. "your order shipped") would need the app to also
/// send its token to the WordPress backend and store it against the
/// logged-in user -- not wired up yet.
const String allUsersTopic = 'all_users';

const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'default_channel',
  'إشعارات عامة',
  description: 'إشعارات دار البراق',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

class PushNotifications {
  PushNotifications._();

  static Future<void> init() async {
    // Android doesn't show a system notification banner on its own for a
    // message that arrives while the app is already in the foreground (only
    // background/terminated messages get that automatically) -- flutter_
    // local_notifications displays one manually in that case, using the
    // same channel/importance as a "real" FCM notification.
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.subscribeToTopic(allUsersTopic);

    final token = await messaging.getToken();
    debugPrint('FCM token: $token');

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification tapped: ${message.notification?.title}');
    });
  }
}
