import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:snoozio/features/diary/logic/sleep_diary_controller.dart';
import 'package:snoozio/features/diary/presentation/sleep_entry_detail_dialog.dart';
import 'package:intl/intl.dart';

class SleepDiaryCard extends StatelessWidget {
  final SleepDiaryEntry entry;
  final SleepDiaryController controller;

  const SleepDiaryCard({
    super.key,
    required this.entry,
    required this.controller,
  });

  void _showDetailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          SleepEntryDetailDialog(entry: entry, controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qualityColor = Color(controller.getColorForQuality(entry.quality));
    final emoji = controller.getEmojiForQuality(entry.quality);
    final dateFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('h:mm a');

    return GestureDetector(
      onTap: () => _showDetailDialog(context),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF240046).withValues(alpha: 0.5),
              const Color(0xFF10002B).withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: qualityColor.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: qualityColor.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(entry.date),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(emoji, style: const TextStyle(fontSize: 28)),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    icon: HugeIcons.strokeRoundedMoon02,
                    label: 'Bedtime',
                    time: timeFormat.format(entry.bedtime),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeInfo(
                    icon: HugeIcons.strokeRoundedSun03,
                    label: 'Wake',
                    time: timeFormat.format(entry.wakeTime),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sleep Efficiency',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${entry.sleepEfficiency.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: qualityColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: entry.sleepEfficiency / 100,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(qualityColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo({
    required List<List<dynamic>> icon,
    required String label,
    required String time,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HugeIcon(icon: icon, size: 14, color: Colors.white54),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
