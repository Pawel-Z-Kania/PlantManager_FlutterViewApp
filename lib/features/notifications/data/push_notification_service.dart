import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../../firebase_options.dart';

class PushNotificationService {
  /// Backend wysyła alarmy na ten temat; musi być zgodny z `api/_lib/fcm.js`.
  static const topic = 'pot-alerts';

  final List<StreamSubscription<RemoteMessage>> _subscriptions = [];
  bool _disposed = false;

  /// Błąd inicjalizacji (np. brak Google Play services) nie może blokować reszty aplikacji.
  Future<void> start({
    required void Function(String text) onForegroundAlert,
    required VoidCallback onOpenedFromNotification,
  }) async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await messaging.subscribeToTopic(topic);
      if (_disposed) return;

      _subscriptions.add(FirebaseMessaging.onMessage.listen((message) {
        final text = _alertText(message);
        if (text != null) onForegroundAlert(text);
      }));
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((_) => onOpenedFromNotification()),
      );
    } catch (e) {
      debugPrint('[PushNotificationService] start failed: $e');
    }
  }

  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  String? _alertText(RemoteMessage message) {
    final notification = message.notification;
    final parts = [
      for (final part in [notification?.title, notification?.body])
        if (part != null && part.isNotEmpty) part,
    ];
    return parts.isEmpty ? null : parts.join(': ');
  }
}
