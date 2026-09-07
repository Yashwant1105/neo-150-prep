class WebPushSubscriptionData {
  final String endpoint;
  final String p256dh;
  final String auth;
  final Map<String, dynamic> metadata;

  const WebPushSubscriptionData({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
    required this.metadata,
  });
}

Future<bool> webPushSupported() async => false;

Future<WebPushSubscriptionData?> enableWebPush(String vapidPublicKey) async =>
    null;

Future<WebPushSubscriptionData?> currentWebPushSubscription() async => null;

Future<void> unsubscribeWebPush() async {}
