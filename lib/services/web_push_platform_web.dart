import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'dart:js_interop';

import 'web_push_platform_stub.dart';

Future<bool> webPushSupported() async {
  try {
    return web.window.isSecureContext && web.Notification.permission.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<WebPushSubscriptionData?> enableWebPush(String vapidPublicKey) async {
  if (!await webPushSupported() || vapidPublicKey.isEmpty) return null;

  final permission = await web.Notification.requestPermission().toDart;
  if (permission.toDart != 'granted') return null;

  final registration = await web.window.navigator.serviceWorker
      .register(
        '/push-scope/push_service_worker.js'.toJS,
        web.RegistrationOptions(scope: '/push-scope/'),
      )
      .toDart;

  final existing = await registration.pushManager.getSubscription().toDart;
  final subscription = existing ??
      await registration.pushManager
          .subscribe(
            web.PushSubscriptionOptionsInit(
              userVisibleOnly: true,
              applicationServerKey: _decodeBase64Url(vapidPublicKey).toJS,
            ),
          )
          .toDart;

  final p256dh = subscription.getKey('p256dh');
  final auth = subscription.getKey('auth');
  if (p256dh == null || auth == null) return null;

  return WebPushSubscriptionData(
    endpoint: subscription.endpoint,
    p256dh: _encodeBase64Url(p256dh.toDart),
    auth: _encodeBase64Url(auth.toDart),
    metadata: <String, dynamic>{
      'expirationTime': subscription.expirationTime,
    },
  );
}

Future<WebPushSubscriptionData?> currentWebPushSubscription() async {
  if (!await webPushSupported()) return null;

  final registration = await web.window.navigator.serviceWorker
      .register(
        '/push-scope/push_service_worker.js'.toJS,
        web.RegistrationOptions(scope: '/push-scope/'),
      )
      .toDart;
  final subscription = await registration.pushManager.getSubscription().toDart;
  if (subscription == null) return null;

  final p256dh = subscription.getKey('p256dh');
  final auth = subscription.getKey('auth');
  if (p256dh == null || auth == null) return null;

  return WebPushSubscriptionData(
    endpoint: subscription.endpoint,
    p256dh: _encodeBase64Url(p256dh.toDart),
    auth: _encodeBase64Url(auth.toDart),
    metadata: <String, dynamic>{
      'expirationTime': subscription.expirationTime,
    },
  );
}

Future<void> unsubscribeWebPush() async {
  if (!await webPushSupported()) return;

  final registration = await web.window.navigator.serviceWorker
      .register(
        '/push-scope/push_service_worker.js'.toJS,
        web.RegistrationOptions(scope: '/push-scope/'),
      )
      .toDart;
  final subscription = await registration.pushManager.getSubscription().toDart;
  await subscription?.unsubscribe().toDart;
}

Uint8List _decodeBase64Url(String value) {
  final normalized = value.padRight((value.length + 3) ~/ 4 * 4, '=');
  return Uint8List.fromList(base64Url.decode(normalized));
}

String _encodeBase64Url(ByteBuffer buffer) {
  return base64UrlEncode(buffer.asUint8List()).replaceAll('=', '');
}
