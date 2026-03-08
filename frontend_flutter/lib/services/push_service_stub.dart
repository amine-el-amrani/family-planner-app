// Stub for non-web platforms
class PushService {
  static Future<void> initialize() async {}
  static Future<bool> subscribeAndRegister() async => false;
}
