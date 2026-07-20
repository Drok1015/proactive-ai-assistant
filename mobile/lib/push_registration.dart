import 'package:flutter/services.dart';

import 'api_client.dart';

/// Native Android/iOS project integrated with JPush should expose a registrationId
/// through this channel after notification permission has been granted.
class PushRegistration {
  static const _channel = MethodChannel('proactive_ai/push');

  static Future<void> registerCurrentDevice(ApiClient api) async {
    final data = await _channel.invokeMapMethod<String, dynamic>('registrationInfo');
    if (data == null || data['registrationId'] == null || data['platform'] == null) return;
    await _channel.invokeMethod('markRegistered');
    // The native bridge is intentionally credential-free. JPush credentials stay on the backend.
    await _postRegistration(api, data);
  }

  static Future<void> _postRegistration(ApiClient api, Map<String, dynamic> data) async {
    await api.registerDevice(
      platform: data['platform'] as String,
      registrationId: data['registrationId'] as String,
    );
  }
}
