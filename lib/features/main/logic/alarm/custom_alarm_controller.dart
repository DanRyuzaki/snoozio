import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:snoozio/core/background/background_service_manager.dart' as bg;

class CustomAlarm {
  final String id;
  final String name;
  final String time;
  final bool isEnabled;
  final List<int> repeatDays;
  final String soundId;
  final String? soundPath;
  final bool vibrate;
  final DateTime createdAt;

  CustomAlarm({
    required this.id,
    required this.name,
    required this.time,
    required this.isEnabled,
    required this.repeatDays,
    required this.soundId,
    this.soundPath,
    this.vibrate = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'time': time,
      'isEnabled': isEnabled,
      'repeatDays': repeatDays,
      'soundId': soundId,
      'soundPath': soundPath,
      'vibrate': vibrate,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomAlarm.fromJson(Map<String, dynamic> json) {
    return CustomAlarm(
      id: json['id'],
      name: json['name'],
      time: json['time'],
      isEnabled: json['isEnabled'] ?? false,
      repeatDays: List<int>.from(json['repeatDays'] ?? []),
      soundId: json['soundId'] ?? 'default',
      soundPath: json['soundPath'],
      vibrate: json['vibrate'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  CustomAlarm copyWith({
    String? id,
    String? name,
    String? time,
    bool? isEnabled,
    List<int>? repeatDays,
    String? soundId,
    String? soundPath,
    bool? vibrate,
    DateTime? createdAt,
  }) {
    return CustomAlarm(
      id: id ?? this.id,
      name: name ?? this.name,
      time: time ?? this.time,
      isEnabled: isEnabled ?? this.isEnabled,
      repeatDays: repeatDays ?? this.repeatDays,
      soundId: soundId ?? this.soundId,
      soundPath: soundPath ?? this.soundPath,
      vibrate: vibrate ?? this.vibrate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get repeatPattern {
    if (repeatDays.isEmpty) return 'One time';
    if (repeatDays.length == 7) return 'Every day';
    if (repeatDays.length == 5 &&
        !repeatDays.contains(5) &&
        !repeatDays.contains(6)) {
      return 'Weekdays';
    }
    if (repeatDays.length == 2 &&
        repeatDays.contains(5) &&
        repeatDays.contains(6)) {
      return 'Weekends';
    }

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return repeatDays.map((i) => days[i]).join(', ');
  }
}

class CustomAlarmController extends ChangeNotifier {
  static const String _storageKey = 'custom_alarms';
  List<CustomAlarm> _alarms = [];

  List<CustomAlarm> get alarms => List.unmodifiable(_alarms);

  Future<void> initialize() async {
    await _loadAlarms();
    await _rescheduleAllAlarms();
  }

  Future<void> _loadAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = prefs.getString(_storageKey);

      if (alarmsJson != null) {
        final List<dynamic> decoded = json.decode(alarmsJson);
        _alarms = decoded.map((json) => CustomAlarm.fromJson(json)).toList();

        _alarms.sort((a, b) => _compareTime(a.time, b.time));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading alarms: $e');
    }
  }

  Future<void> _saveAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = json.encode(_alarms.map((a) => a.toJson()).toList());
      await prefs.setString(_storageKey, alarmsJson);
    } catch (e) {
      debugPrint('Error saving alarms: $e');
    }
  }

  Future<void> addAlarm(CustomAlarm alarm) async {
    _alarms.add(alarm);
    _alarms.sort((a, b) => _compareTime(a.time, b.time));

    await _saveAlarms();

    if (alarm.isEnabled) {
      await _scheduleAlarm(alarm);
    }

    notifyListeners();
  }

  Future<void> updateAlarm(String alarmId, CustomAlarm updatedAlarm) async {
    final index = _alarms.indexWhere((a) => a.id == alarmId);
    if (index == -1) return;

    final oldAlarm = _alarms[index];
    _alarms[index] = updatedAlarm;
    _alarms.sort((a, b) => _compareTime(a.time, b.time));

    await _saveAlarms();

    await _cancelAlarmSchedule(oldAlarm);

    if (updatedAlarm.isEnabled) {
      await _scheduleAlarm(updatedAlarm);
    }

    notifyListeners();
  }

  Future<void> deleteAlarm(String alarmId) async {
    final alarm = _alarms.firstWhere((a) => a.id == alarmId);

    await _cancelAlarmSchedule(alarm);

    _alarms.removeWhere((a) => a.id == alarmId);
    await _saveAlarms();

    notifyListeners();
  }

  Future<void> toggleAlarm(String alarmId, bool enabled) async {
    final index = _alarms.indexWhere((a) => a.id == alarmId);
    if (index == -1) return;

    final alarm = _alarms[index];
    final updatedAlarm = alarm.copyWith(isEnabled: enabled);
    _alarms[index] = updatedAlarm;

    await _saveAlarms();

    if (enabled) {
      await _scheduleAlarm(updatedAlarm);
    } else {
      await _cancelAlarmSchedule(alarm);
    }

    notifyListeners();
  }

  Future<void> _scheduleAlarm(CustomAlarm alarm) async {
    try {
      if (alarm.repeatDays.isEmpty) {
        final scheduled = await bg.BackgroundServiceManager.scheduleAlarm(
          activityId: alarm.id,
          activityName: alarm.name,
          time: alarm.time,
          dayNumber: 0,
          snoozeMinutes: 0,
        );

        if (!scheduled) {
          debugPrint('⚠️ Failed to schedule one-time alarm: ${alarm.name}');
        }
      } else {
        final nextOccurrence = _getNextOccurrence(alarm);
        if (nextOccurrence != null) {
          final timeString = _formatTime(nextOccurrence);
          await bg.BackgroundServiceManager.scheduleAlarm(
            activityId: alarm.id,
            activityName: alarm.name,
            time: timeString,
            dayNumber: 0,
            snoozeMinutes: 0,
          );
        }
      }

      debugPrint('⏰ Scheduled alarm: ${alarm.name} at ${alarm.time}');
    } catch (e) {
      debugPrint('❌ Error scheduling alarm: $e');
    }
  }

  Future<void> _cancelAlarmSchedule(CustomAlarm alarm) async {
    try {
      await bg.BackgroundServiceManager.cancelActivityReminder(alarm.id);
      debugPrint('🛑 Cancelled alarm: ${alarm.name}');
    } catch (e) {
      debugPrint('❌ Error cancelling alarm: $e');
    }
  }

  Future<void> _rescheduleAllAlarms() async {
    for (final alarm in _alarms.where((a) => a.isEnabled)) {
      await _scheduleAlarm(alarm);
    }
  }

  DateTime? _getNextOccurrence(CustomAlarm alarm) {
    if (alarm.repeatDays.isEmpty) return null;

    final now = DateTime.now();
    final scheduledTime = _parseTimeString(alarm.time);
    if (scheduledTime == null) return null;

    if (alarm.repeatDays.contains(now.weekday - 1)) {
      final today = DateTime(
        now.year,
        now.month,
        now.day,
        scheduledTime.hour,
        scheduledTime.minute,
      );
      if (today.isAfter(now)) return today;
    }

    for (int i = 1; i <= 7; i++) {
      final checkDate = now.add(Duration(days: i));
      if (alarm.repeatDays.contains(checkDate.weekday - 1)) {
        return DateTime(
          checkDate.year,
          checkDate.month,
          checkDate.day,
          scheduledTime.hour,
          scheduledTime.minute,
        );
      }
    }

    return null;
  }

  DateTime? _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return null;

      final hour = int.parse(parts[0].trim());
      final minute = int.parse(parts[1].split(' ')[0].trim());
      final isPm = timeStr.toLowerCase().contains('pm');

      var scheduledHour = hour;
      if (isPm && hour != 12) {
        scheduledHour += 12;
      } else if (!isPm && hour == 12) {
        scheduledHour = 0;
      }

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, scheduledHour, minute);
    } catch (e) {
      return null;
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  int _compareTime(String time1, String time2) {
    final dt1 = _parseTimeString(time1);
    final dt2 = _parseTimeString(time2);

    if (dt1 == null || dt2 == null) return 0;
    return dt1.compareTo(dt2);
  }

  int get enabledAlarmsCount => _alarms.where((a) => a.isEnabled).length;

  static String generateId() {
    return 'custom_alarm_${DateTime.now().millisecondsSinceEpoch}';
  }
}
