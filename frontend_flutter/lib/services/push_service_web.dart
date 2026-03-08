// Web implementation using dart:js_interop (Dart 3 / Flutter 3.x)
import 'dart:js_interop';
import '../core/api_client.dart';

@JS('initPushSW')
external JSPromise<JSAny?> _initPushSW();

@JS('subscribeToPush')
external JSPromise<JSAny?> _subscribeToPush(JSString vapidKey);

class PushService {
  static final _api = ApiClient();

  /// Register the push service worker (call once at app start).
  static Future<void> initialize() async {
    try {
      await _initPushSW().toDart;
    } catch (_) {}
  }

  /// Request permission, subscribe, and send subscription to backend.
  /// Returns true if subscription was successfully saved.
  static Future<bool> subscribeAndRegister() async {
    final res = await _api.dio.get('/users/push/vapid-key');
    final vapidKey = (res.data['public_key'] as String?) ?? '';
    if (vapidKey.isEmpty) throw Exception('VAPID key not configured on server');

    final jsResult = await _subscribeToPush(vapidKey.toJS).toDart;
    final subJson = jsResult?.dartify()?.toString();
    if (subJson == null || !subJson.startsWith('{')) {
      // null = permission denied or SW not ready
      return false;
    }

    await _api.dio.post(
      '/users/me/push-subscription',
      data: {'subscription': subJson},
    );
    return true;
  }
}
