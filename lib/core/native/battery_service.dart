import 'package:flutter/services.dart';

class BatteryService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.cortex/battery',
  );

  static Future<int> getBatteryLevel() async {
    try {
      final int result = await _channel.invokeMethod('getBatteryLevel');
      return result;
    } on PlatformException catch (_) {
      // Default fallback if unavailable or not on Android
      return 100;
    }
  }
}
