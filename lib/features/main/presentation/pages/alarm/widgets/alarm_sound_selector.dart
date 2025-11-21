import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AlarmSoundSelector extends StatefulWidget {
  final String currentSoundId;
  final Function(String) onSoundSelected;

  const AlarmSoundSelector({
    super.key,
    required this.currentSoundId,
    required this.onSoundSelected,
  });

  @override
  State<AlarmSoundSelector> createState() => _AlarmSoundSelectorState();
}

class _AlarmSoundSelectorState extends State<AlarmSoundSelector> {
  void _selectSound(String soundId) {
    widget.onSoundSelected(soundId);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.35,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2E1A47).withValues(alpha: 0.98),
            const Color(0xFF1A0D2E).withValues(alpha: 0.98),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF9D4EDD).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Alarm Sound',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap to select',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
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

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedInformationCircle,
                      size: 20,
                      color: Color(0xFFE0AAFF),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sound preview available when notifications are enabled',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selectSound('default'),
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text('Default'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectSound('pick_file'),
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedFolders,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text('Pick from device…'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
