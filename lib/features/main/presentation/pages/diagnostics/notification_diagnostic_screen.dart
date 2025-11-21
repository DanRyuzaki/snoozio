import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snoozio/core/background/background_service_manager.dart';
import 'package:snoozio/core/notification/notification_service.dart';
import 'package:snoozio/core/notification/notification_debug_helper.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zhi_starry_sky/starry_sky.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationDiagnosticScreen extends StatefulWidget {
  const NotificationDiagnosticScreen({super.key});

  @override
  State<NotificationDiagnosticScreen> createState() =>
      _NotificationDiagnosticScreenState();
}

class _NotificationDiagnosticScreenState
    extends State<NotificationDiagnosticScreen> {
  Map<String, bool> _permissions = {};
  // ignore: unused_field
  List<String> _pendingNotifications = [];
  Map<String, dynamic>? _userStats;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _checkAllPermissions(),
      _checkPendingNotifications(),
      _loadUserStats(),
    ]);
  }

  Future<void> _checkAllPermissions() async {
    setState(() => _isLoading = true);

    final permissions = {
      'Notifications': await Permission.notification.isGranted,
      'Exact Alarms': await Permission.scheduleExactAlarm.isGranted,
      'Battery Optimization':
          await Permission.ignoreBatteryOptimizations.isGranted,
      'Draw Over Apps': await Permission.systemAlertWindow.isGranted,
    };

    setState(() {
      _permissions = permissions;
      _isLoading = false;
    });
  }

  Future<void> _checkPendingNotifications() async {
    try {
      final pending = await NotificationService.getPendingNotifications();
      setState(() {
        _pendingNotifications = pending
            .map((n) => 'ID: ${n.id} - ${n.title ?? "No title"}')
            .toList();
      });
    } catch (e) {
      debugPrint('Error checking pending notifications: $e');
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _userStats = {
          'currentDay': data['currentDay'] ?? 0,
          'assessment': data['assessment'] ?? 0,
          'programStartDate': (data['programStartDate'] as Timestamp?)
              ?.toDate()
              .toString()
              .split(' ')[0],
          'currentDayDate': (data['currentDayDate'] as Timestamp?)
              ?.toDate()
              .toString()
              .split(' ')[0],
          'userId': user.uid,
          'scheduledAlarms':
              prefs.getStringList('scheduled_alarm_ids')?.length ?? 0,
        };
      });
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }
  }

  Future<void> _forceRescheduleAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E0F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Force Reschedule All?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will cancel all existing notifications and reschedule today\'s reminders.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
            ),
            child: const Text(
              'Reschedule',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    await NotificationDebugHelper.forceRescheduleAll();
    await _checkPendingNotifications();
    await _loadUserStats();

    if (!mounted) return;

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ All reminders rescheduled successfully!'),
        backgroundColor: Color(0xFFFF9800),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E0F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear All Notifications?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will cancel ALL pending notifications. You can reschedule them afterwards.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    await BackgroundServiceManager.cancelAllReminders();
    await _checkPendingNotifications();

    if (!mounted) return;

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ All notifications cleared'),
        backgroundColor: Color(0xFFE74C3C),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openSettings(Permission permission) async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Developer Tools'),
        backgroundColor: const Color(0xFF1E0F33),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColorFiltered(
            colorFilter: ColorFilter.matrix([
              -1,
              0,
              0,
              0,
              255,
              0,
              -1,
              0,
              0,
              255,
              0,
              0,
              -1,
              0,
              255,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: StarrySkyView(),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF2E1A47).withValues(alpha: 0.8),
                  const Color(0xFF1A0D2E).withValues(alpha: 0.9),
                  const Color(0xFF0D0A1A).withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF9D4EDD)),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      if (_userStats != null) _buildUserStatsSection(),
                      const SizedBox(height: 16),
                      _buildPermissionsSection(),
                      const SizedBox(height: 16),
                      _buildAdvancedTools(),
                      const SizedBox(height: 16),
                      _buildDeviceInstructions(),
                      const SizedBox(height: 100),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCode,
                color: Color(0xFF6C5CE7),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Developer Tools',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Diagnostic tools for testing notifications, checking permissions, and troubleshooting issues. Use these tools to ensure Snoozio works perfectly on your device.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedUserAccount,
                color: Color(0xFFE0AAFF),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'User Information',
                style: TextStyle(
                  color: Color(0xFFE0AAFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatRow('Current Day', '${_userStats!['currentDay']}'),
          _buildStatRow(
            'Care Plan',
            _getCarePlanName(_userStats!['assessment']),
          ),
          _buildStatRow(
            'Started',
            _userStats!['programStartDate'] ?? 'Unknown',
          ),
          _buildStatRow('Day Date', _userStats!['currentDayDate'] ?? 'Unknown'),
          _buildStatRow(
            'Scheduled Alarms',
            '${_userStats!['scheduledAlarms']}',
          ),
          const SizedBox(height: 8),
          Text(
            'User ID: ${_userStats!['userId']}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _getCarePlanName(int assessment) {
    switch (assessment) {
      case 0:
        return 'Normal Sleep';
      case 1:
        return 'Mild';
      case 2:
        return 'Moderate';
      case 3:
        return 'Severe';
      default:
        return 'Unassigned';
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Permissions Status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: _checkAllPermissions,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                color: Color(0xFF9D4EDD),
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._permissions.entries.map(
          (entry) => _buildPermissionItem(entry.key, entry.value),
        ),
      ],
    );
  }

  Widget _buildPermissionItem(String name, bool granted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: granted
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: granted
                ? HugeIcons.strokeRoundedCheckmarkCircle02
                : HugeIcons.strokeRoundedCancelCircle,
            color: granted ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          if (!granted)
            TextButton(
              onPressed: () => _openSettings(Permission.notification),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9D4EDD),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
              child: const Text('Enable'),
            ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTools() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4834D4).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4834D4).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedSettings02,
                color: Color(0xFFFF9800),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Advanced Tools',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _forceRescheduleAll,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Reschedule All Reminders',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _clearAllNotifications,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Clear All Notifications',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedSmartPhone01,
                color: Colors.orange,
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Device-Specific Instructions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'For devices with aggressive battery optimization (Xiaomi, Vivo, Oppo, Huawei, OnePlus, Samsung, etc.), enable these settings:',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _buildInstructionItem('1. Enable Autostart/Auto-launch for Snoozio'),
          _buildInstructionItem('2. Disable battery optimization'),
          _buildInstructionItem('3. Allow background data usage'),
          _buildInstructionItem(
            '4. Enable "High background power consumption"',
          ),
          _buildInstructionItem(
            '5. Lock app in Recent Apps (prevent auto-kill)',
          ),
          const SizedBox(height: 12),
          const Text(
            '⚠️ These restrictions vary by manufacturer and can prevent notifications from working properly.',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => openAppSettings(),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSettings02,
                size: 18,
                color: Colors.white,
              ),
              label: const Text('Open App Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: Colors.orange, fontSize: 16),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
