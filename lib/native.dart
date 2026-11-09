import 'package:flutter/services.dart';

class Native {
  static const MethodChannel _c = MethodChannel('selema/gold');

  static Future<Object?> _call(String m, [Map<String, Object?>? a]) async {
    try {
      return await _c.invokeMethod<Object?>(m, a);
    } catch (_) {
      return null;
    }
  }

  static Future<void> sync(String deals, String settings) async {
    await _call('sync', {'deals': deals, 'settings': settings});
  }

  static Future<String?> takeEvents() async {
    final r = await _call('getEvents');
    return r is String ? r : null;
  }

  static Future<void> stopAlarm() async {
    await _call('stopAlarm');
  }

  static Future<bool> isRinging() async => (await _call('isRinging')) == true;
  static Future<bool> isRunning() async => (await _call('isRunning')) == true;

  static Future<void> testAlert(String title, String body, bool sound, bool push) async {
    await _call('testAlert', {'title': title, 'body': body, 'sound': sound, 'push': push});
  }

  static Future<void> requestNotifications() async {
    await _call('requestNotif');
  }

  static Future<void> requestBatteryExemption() async {
    await _call('batteryExempt');
  }

  static Future<bool> isBatteryExempt() async => (await _call('isBatteryExempt')) == true;
}
