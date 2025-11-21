import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hugeicons/hugeicons.dart';

class PermissionRequestScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionRequestScreen({
    super.key,
    required this.onPermissionsGranted,
  });

  @override
  State<PermissionRequestScreen> createState() =>
      _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  bool _isRequesting = false;
  Map<String, bool> _permissionStatus = {
    'notifications': false,
    'exactAlarm': false,
    'battery': false,
  };

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  Future<void> _checkCurrentPermissions() async {
    final notif = await Permission.notification.isGranted;
    final alarm = await Permission.scheduleExactAlarm.isGranted;
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;

    setState(() {
      _permissionStatus = {
        'notifications': notif,
        'exactAlarm': alarm,
        'battery': battery,
      };
    });

    if (notif && alarm && battery) {
      widget.onPermissionsGranted();
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isRequesting = true);

    final notifStatus = await Permission.notification.request();
    setState(() {
      _permissionStatus['notifications'] = notifStatus.isGranted;
    });

    if (!_permissionStatus['exactAlarm']!) {
      final alarmStatus = await Permission.scheduleExactAlarm.request();
      setState(() {
        _permissionStatus['exactAlarm'] = alarmStatus.isGranted;
      });
    }

    if (!_permissionStatus['battery']!) {
      final batteryStatus = await Permission.ignoreBatteryOptimizations
          .request();
      setState(() {
        _permissionStatus['battery'] = batteryStatus.isGranted;
      });
    }

    setState(() => _isRequesting = false);

    if (_permissionStatus.values.every((granted) => granted)) {
      widget.onPermissionsGranted();
    } else {
      _showPermissionDeniedDialog();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E0F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle,
              color: Color(0xFFE74C3C),
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Permissions Required',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Snoozio needs these permissions to send you sleep activity reminders. Without them, the app cannot notify you at the right times.\n\nYou can grant permissions in Settings.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
            ),
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0D2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                      const Color(0xFF4834D4).withValues(alpha: 0.2),
                    ],
                  ),
                ),
                child: const Center(
                  child: Text('🌙', style: TextStyle(fontSize: 50)),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Allow Notifications',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'To help you build better sleep habits, Snoozio needs permission to:',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              _buildPermissionCard(
                icon: HugeIcons.strokeRoundedNotification03,
                title: 'Send Notifications',
                description: 'Remind you of daily sleep activities',
                isGranted: _permissionStatus['notifications']!,
              ),

              const SizedBox(height: 16),

              _buildPermissionCard(
                icon: HugeIcons.strokeRoundedAlarmClock,
                title: 'Schedule Exact Alarms',
                description: 'Deliver reminders at precise times',
                isGranted: _permissionStatus['exactAlarm']!,
              ),

              const SizedBox(height: 16),

              _buildPermissionCard(
                icon: HugeIcons.strokeRoundedBatteriesEnergy,
                title: 'Run in Background',
                description: 'Work even when the app is closed',
                isGranted: _permissionStatus['battery']!,
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isRequesting ? null : _requestAllPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isRequesting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Grant Permissions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  widget.onPermissionsGranted();
                },
                child: Text(
                  'Skip for now (not recommended)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required List<List<dynamic>> icon,
    required String title,
    required String description,
    required bool isGranted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF27AE60).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFF27AE60).withValues(alpha: 0.2)
                  : const Color(0xFF6C5CE7).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: icon,
              color: isGranted
                  ? const Color(0xFF27AE60)
                  : const Color(0xFF6C5CE7),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isGranted)
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                        color: Color(0xFF27AE60),
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
