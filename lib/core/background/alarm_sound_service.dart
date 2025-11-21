import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmSoundService {
  static const MethodChannel _channel = MethodChannel('com.snoozio.app/alarm');

  static Future<bool> playAlarmSound(String alarmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = prefs.getString('custom_alarms');

      String? soundPath;
      String soundType = 'default';

      if (alarmsJson != null) {
        final List<dynamic> alarms = json.decode(alarmsJson);
        final alarm = alarms.firstWhere(
          (a) => a['id'] == alarmId,
          orElse: () => null,
        );

        if (alarm != null) {
          soundType = alarm['soundId'] ?? 'default';
          soundPath = alarm['soundPath'];

          debugPrint('🔊 Playing alarm: soundType=$soundType, path=$soundPath');
        }
      }

      final result = await _channel.invokeMethod('playAlarmSound', {
        'soundPath': soundPath,
        'soundType': soundType,
      });

      debugPrint('✅ Alarm sound started (looping)');
      return result == true;
    } catch (e) {
      debugPrint('❌ Error playing alarm sound: $e');
      return false;
    }
  }

  static Future<bool> stopAlarmSound() async {
    try {
      final result = await _channel.invokeMethod('stopAlarmSound');
      debugPrint('🛑 Alarm sound stopped');
      return result == true;
    } catch (e) {
      debugPrint('❌ Error stopping alarm sound: $e');
      return false;
    }
  }

  static Future<bool> isAlarmPlaying() async {
    try {
      final result = await _channel.invokeMethod('isAlarmPlaying');
      return result == true;
    } catch (e) {
      debugPrint('❌ Error checking alarm status: $e');
      return false;
    }
  }
}
