import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'supabase_service.dart';
import 'web_push_platform_stub.dart'
    if (dart.library.js_interop) 'web_push_platform_web.dart' as web_push;

const webPushVapidPublicKey = String.fromEnvironment(
  'WEB_PUSH_VAPID_PUBLIC_KEY',
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!_isAndroid) return;

  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.messageId}');
}

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  static const _androidChannel = AndroidNotificationChannel(
    'achievement_notifications',
    'Achievement notifications',
    description: 'Notifications for newly unlocked achievements.',
    importance: Importance.high,
  );

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _registeredToken;
  bool _initialized = false;

  Future<void> initialize() async {
    if ((!_isAndroid && !kIsWeb) || _initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    await Firebase.initializeApp();

    debugPrint('Initializing local notifications');
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(initializationSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
    debugPrint('Local notifications initialized');

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    _messageSubscription = FirebaseMessaging.onMessage.listen(_handleMessage);
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );
    _tokenSubscription = _messaging.onTokenRefresh.listen(_handleTokenRefresh);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }

    _initialized = true;
  }

  Future<bool> enableForCurrentUser() async {
    if (SupabaseService.currentSession == null) return false;

    if (kIsWeb) {
      await initialize();
      final subscription = await web_push.enableWebPush(
        webPushVapidPublicKey,
      );
      if (subscription == null) return false;

      await SupabaseService().setNotificationsEnabled(true);
      await SupabaseService().upsertWebPushEndpoint(
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
        metadata: subscription.metadata,
      );
      return true;
    }

    if (!_isAndroid) return false;

    await initialize();

    final settings = await SupabaseService().fetchNotificationSettings();
    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }

    if (settings['notifications_enabled'] != true) {
      await SupabaseService().setNotificationsEnabled(true);
    }

    await registerCurrentToken();
    return true;
  }

  Future<void> disableForCurrentUser() async {
    if (SupabaseService.currentSession == null) return;

    if (kIsWeb) {
      final subscription = await web_push.currentWebPushSubscription();
      if (subscription != null) {
        await SupabaseService().deactivateWebPushEndpoint(
          subscription.endpoint,
        );
      }
      await web_push.unsubscribeWebPush();
      await SupabaseService().setNotificationsEnabled(false);
      return;
    }

    if (!_isAndroid) return;

    await SupabaseService().setNotificationsEnabled(false);
    await deactivateCurrentEndpoint();
  }

  Future<void> syncForCurrentUser() async {
    debugPrint('[NOTIF SYNC] entered');
    debugPrint(
      '[NOTIF SYNC] currentSession: ${SupabaseService.currentSession != null}',
    );
    debugPrint(
      '[NOTIF SYNC] platform: ${kIsWeb ? 'web' : _isAndroid ? 'android' : 'other'}',
    );
    try {
      if (SupabaseService.currentSession == null) return;

      if (kIsWeb) {
        await initialize();
        debugPrint('[NOTIF SYNC] web registration starting');
        await registerCurrentWebPushSubscription();
        debugPrint('[NOTIF SYNC] web registration completed');
        debugPrint('[NOTIF SYNC] sync completed');
        return;
      }

      if (!_isAndroid) return;

      await initialize();

      final settings = await SupabaseService().fetchNotificationSettings();
      if (settings['notifications_enabled'] == true) {
        await registerCurrentToken();
      }
      debugPrint('[NOTIF SYNC] sync completed');
    } catch (error, stackTrace) {
      debugPrint('Notification endpoint sync failed: $error\n$stackTrace');
    }
  }

  Future<void> registerCurrentToken() async {
    if (!_isAndroid || SupabaseService.currentSession == null) return;

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    await SupabaseService().upsertFcmEndpoint(token);
    _registeredToken = token;
  }

  Future<void> registerCurrentWebPushSubscription() async {
    debugPrint('[WEB PUSH] registration entered');
    if (!kIsWeb || SupabaseService.currentSession == null) return;

    final subscription = await web_push.currentWebPushSubscription();
    debugPrint('[WEB PUSH] subscription exists: ${subscription != null}');
    debugPrint(
      '[WEB PUSH] endpoint: ${subscription == null ? '<none>' : subscription.endpoint.substring(0, subscription.endpoint.length < 30 ? subscription.endpoint.length : 30)}',
    );
    if (subscription == null) return;

    await SupabaseService().upsertWebPushEndpoint(
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth,
      metadata: subscription.metadata,
    );
    debugPrint('[WEB PUSH] upsert completed');
    await SupabaseService().deactivateOtherWebPushEndpoints(
      subscription.endpoint,
    );
    debugPrint('[WEB PUSH] stale endpoint cleanup completed');
  }

  Future<void> deactivateCurrentEndpoint() async {
    if (kIsWeb) {
      final subscription = await web_push.currentWebPushSubscription();
      if (subscription == null) return;

      await SupabaseService().deactivateWebPushEndpoint(
        subscription.endpoint,
      );
      return;
    }

    if (!_isAndroid) return;

    final token = _registeredToken ?? await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    final userId = SupabaseService.currentSession?.user.id;
    if (userId == null) return;

    await SupabaseService().deactivateFcmEndpoint(token);
    _registeredToken = null;
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
    _tokenSubscription = null;
    _messageSubscription = null;
    _openedSubscription = null;
    _initialized = false;
  }

  void _handleTokenRefresh(String token) {
    unawaited(_registerRefreshedToken(token));
  }

  Future<void> _registerRefreshedToken(String token) async {
    if (SupabaseService.currentSession == null) return;

    final settings = await SupabaseService().fetchNotificationSettings();
    if (settings['notifications_enabled'] != true) return;

    await SupabaseService().upsertFcmEndpoint(token);
    _registeredToken = token;
  }

  void _handleMessage(RemoteMessage message) {
    debugPrint(
      'FCM foreground message: ${message.messageId}, '
      'category: ${message.data['category']}',
    );
    unawaited(_showForegroundNotification(message));
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title ??
        message.data['title'] ??
        message.data['notification_title'] ??
        'Neo 150 Prep';
    final body = message.notification?.body ??
        message.data['body'] ??
        message.data['notification_body'] ??
        'You have a new notification.';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    final notificationId = message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
    );
    debugPrint('Local notification shown: $notificationId');
  }

  void _handleOpenedMessage(RemoteMessage message) {
    debugPrint(
      'FCM notification opened: ${message.messageId}, '
      'category: ${message.data['category']}',
    );
  }
}
