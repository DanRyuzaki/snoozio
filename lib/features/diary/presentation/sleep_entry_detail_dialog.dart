import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:snoozio/features/diary/logic/sleep_diary_controller.dart';
import 'package:intl/intl.dart';

class SleepEntryDetailDialog extends StatelessWidget {
  final SleepDiaryEntry entry;
  final SleepDiaryController controller;

  const SleepEntryDetailDialog({
    super.key,
    required this.entry,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final qualityColor = Color(controller.getColorForQuality(entry.quality));
    final emoji = controller.getEmojiForQuality(entry.quality);
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    final duration = entry.wakeTime.difference(entry.bedtime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF2E1A47).withValues(alpha: 0.98),
              const Color(0xFF1A0D2E).withValues(alpha: 0.98),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: qualityColor.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    qualityColor.withValues(alpha: 0.3),
                    qualityColor.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: qualityColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormat.format(entry.date),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getQualityText(entry.quality),
                          style: TextStyle(
                            color: qualityColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(
                      icon: HugeIcons.strokeRoundedClock04,
                      title: 'Sleep Duration',
                      content:
                          '$hours hours ${minutes > 0 ? '$minutes minutes' : ''}',
                      color: const Color(0xFF9D4EDD),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            icon: HugeIcons.strokeRoundedMoon02,
                            title: 'Bedtime',
                            content: timeFormat.format(entry.bedtime),
                            color: const Color(0xFF7209B7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(
                            icon: HugeIcons.strokeRoundedSun03,
                            title: 'Wake Time',
                            content: timeFormat.format(entry.wakeTime),
                            color: const Color(0xFFE0AAFF),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _buildSectionTitle('Sleep Efficiency'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            qualityColor.withValues(alpha: 0.2),
                            qualityColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: qualityColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Overall Rating',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${entry.sleepEfficiency.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: qualityColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: entry.sleepEfficiency / 100,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              valueColor: AlwaysStoppedAnimation(qualityColor),
                              minHeight: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (entry.disturbances.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('Sleep Disturbances'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: entry.disturbances.map((disturbance) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const HugeIcon(
                                  icon: HugeIcons.strokeRoundedAlert02,
                                  size: 14,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  disturbance,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('Notes'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF240046).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFF5A189A,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          entry.notes!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    _buildSleepTips(entry.quality),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFE0AAFF),
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoCard({
    required List<List<dynamic>> icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepTips(SleepQuality quality) {
    String tip;
    List<List<dynamic>> tipIcon;

    switch (quality) {
      case SleepQuality.good:
        tip =
            "Great job! You're getting optimal sleep. Keep maintaining your sleep routine!";
        tipIcon = HugeIcons.strokeRoundedCheckmarkCircle02;
        break;
      case SleepQuality.moderate:
        tip =
            "Consider adjusting your bedtime to get closer to 7-9 hours of sleep.";
        tipIcon = HugeIcons.strokeRoundedInformationCircle;
        break;
      case SleepQuality.poor:
        tip =
            "Try to improve your sleep schedule. Aim for 7-9 hours of quality rest.";
        tipIcon = HugeIcons.strokeRoundedAlert02;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7209B7).withValues(alpha: 0.2),
            const Color(0xFF3C096C).withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE0AAFF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          HugeIcon(icon: tipIcon, size: 24, color: const Color(0xFFE0AAFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getQualityText(SleepQuality quality) {
    switch (quality) {
      case SleepQuality.good:
        return 'Good Sleep';
      case SleepQuality.moderate:
        return 'Moderate Sleep';
      case SleepQuality.poor:
        return 'Poor Sleep';
    }
  }
}
