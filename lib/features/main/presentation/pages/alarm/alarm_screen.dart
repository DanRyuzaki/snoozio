import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:snoozio/features/main/logic/alarm/custom_alarm_controller.dart';
import 'package:snoozio/features/main/presentation/pages/alarm/widgets/add_edit_alarm_dialog.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final CustomAlarmController _controller = CustomAlarmController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddAlarmDialog() async {
    final result = await showDialog<CustomAlarm>(
      context: context,
      builder: (context) => const AddEditAlarmDialog(),
    );

    if (result != null) {
      await _controller.addAlarm(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏰ Alarm added successfully!'),
            backgroundColor: Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showEditAlarmDialog(CustomAlarm alarm) async {
    final result = await showDialog<CustomAlarm>(
      context: context,
      builder: (context) => AddEditAlarmDialog(existingAlarm: alarm),
    );

    if (result != null) {
      await _controller.updateAlarm(alarm.id, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Alarm updated!'),
            backgroundColor: Color(0xFF6C5CE7),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteAlarm(CustomAlarm alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E0F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Alarm?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${alarm.name}"?',
          style: const TextStyle(color: Colors.white70),
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
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.deleteAlarm(alarm.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Alarm deleted'),
            backgroundColor: Color(0xFFE74C3C),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      if (_controller.alarms.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: _controller.alarms.length,
                        itemBuilder: (context, index) {
                          final alarm = _controller.alarms[index];
                          return _buildAlarmCard(alarm);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF5A4CC5)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedAlarmClock,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alarms',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your custom wake-up alarms',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _showAddAlarmDialog,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                color: Color(0xFF6C5CE7),
                size: 28,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkBadge02,
                    color: Color(0xFF6C5CE7),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_controller.enabledAlarmsCount} ${_controller.enabledAlarmsCount == 1 ? 'alarm' : 'alarms'} active',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAlarmCard(CustomAlarm alarm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: alarm.isEnabled
              ? [
                  const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                  const Color(0xFF5A4CC5).withValues(alpha: 0.15),
                ]
              : [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.03),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: alarm.isEnabled
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarm.time,
                        style: TextStyle(
                          color: alarm.isEnabled
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alarm.name,
                        style: TextStyle(
                          color: alarm.isEnabled
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 1.1,
                  child: Switch(
                    value: alarm.isEnabled,
                    onChanged: (value) =>
                        _controller.toggleAlarm(alarm.id, value),
                    activeThumbColor: const Color(0xFF6C5CE7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  icon: HugeIcons.strokeRoundedRefresh,
                  label: alarm.repeatPattern,
                ),
                const SizedBox(width: 8),
                if (alarm.vibrate)
                  _buildInfoChip(
                    icon: HugeIcons.strokeRoundedCallRinging01,
                    label: 'Vibrate',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditAlarmDialog(alarm),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedEdit02,
                    color: Color(0xFF6C5CE7),
                    size: 18,
                  ),
                  label: const Text(
                    'Edit',
                    style: TextStyle(color: Color(0xFF6C5CE7)),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _deleteAlarm(alarm),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete02,
                    color: Color(0xFFE74C3C),
                    size: 18,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Color(0xFFE74C3C)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required List<List<dynamic>> icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 14, color: const Color(0xFFE0AAFF)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedAlarmClock,
              size: 64,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No alarms yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first alarm',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddAlarmDialog,
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 20,
              color: Colors.white,
            ),
            label: const Text('Add Alarm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
