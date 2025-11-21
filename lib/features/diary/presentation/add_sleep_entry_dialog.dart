import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:snoozio/features/diary/logic/sleep_diary_controller.dart';

class AddSleepEntryDialog extends StatefulWidget {
  const AddSleepEntryDialog({super.key});

  @override
  State<AddSleepEntryDialog> createState() => _AddSleepEntryDialogState();
}

class _AddSleepEntryDialogState extends State<AddSleepEntryDialog> {
  final SleepDiaryController _controller = SleepDiaryController();

  final DateTime _selectedDate = DateTime.now();
  TimeOfDay _bedtime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  bool _bedtimeYesterday = true;
  final Set<String> _selectedDisturbances = {};
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveSleepEntry() async {
    setState(() => _isLoading = true);

    try {
      final bedtimeDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _bedtimeYesterday ? _selectedDate.day - 1 : _selectedDate.day,
        _bedtime.hour,
        _bedtime.minute,
      );

      final wakeTimeDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _wakeTime.hour,
        _wakeTime.minute,
      );

      final efficiency = _controller.calculateSleepEfficiency(
        bedtimeDate,
        wakeTimeDate,
      );

      final quality = _controller.getSleepQualityFromEfficiency(efficiency);

      final entry = SleepDiaryEntry(
        id: '',
        date: _selectedDate,
        bedtime: bedtimeDate,
        wakeTime: wakeTimeDate,
        quality: quality,
        disturbances: _selectedDisturbances.toList(),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        sleepEfficiency: efficiency,
      );

      await _controller.saveSleepDiaryEntry(entry);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sleep entry saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving entry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
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
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Sleep Entry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Date'),
                    const SizedBox(height: 8),
                    _buildDatePicker(),

                    const SizedBox(height: 24),

                    _buildSectionTitle('Sleep Times'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePicker(
                            label: 'Bedtime',
                            icon: HugeIcons.strokeRoundedMoon02,
                            time: _bedtime,
                            onTimePicked: (time) =>
                                setState(() => _bedtime = time),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimePicker(
                            label: 'Wake Time',
                            icon: HugeIcons.strokeRoundedSun03,
                            time: _wakeTime,
                            onTimePicked: (time) =>
                                setState(() => _wakeTime = time),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildSectionTitle('When did you go to bed?'),
                    const SizedBox(height: 8),
                    _buildBedtimeChoice(),

                    const SizedBox(height: 24),

                    _buildSectionTitle('Sleep Disturbances (Optional)'),
                    const SizedBox(height: 8),
                    _buildDisturbanceChips(),

                    const SizedBox(height: 24),

                    _buildSectionTitle('Notes (Optional)'),
                    const SizedBox(height: 8),
                    _buildNotesField(),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveSleepEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Entry',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar01,
            color: Colors.white70,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required List<List<dynamic>> icon,
    required TimeOfDay time,
    required Function(TimeOfDay) onTimePicked,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onTimePicked(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: icon, size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              time.format(context),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisturbanceChips() {
    final disturbances = _controller.getCommonDisturbances();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: disturbances.map((disturbance) {
        final isSelected = _selectedDisturbances.contains(disturbance);

        return FilterChip(
          label: Text(
            disturbance,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF1A0D2E),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedDisturbances.add(disturbance);
              } else {
                _selectedDisturbances.remove(disturbance);
              }
            });
          },
          backgroundColor: Colors.white.withValues(alpha: 0.9),
          selectedColor: Colors.red.withValues(alpha: 0.5),
          checkmarkColor: Colors.white,
          side: BorderSide(
            color: isSelected
                ? Colors.red.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.2),
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBedtimeChoice() {
    return RadioGroup<bool>(
      groupValue: _bedtimeYesterday,
      onChanged: (value) => setState(() => _bedtimeYesterday = value!),
      child: Row(
        children: [
          Expanded(
            child: RadioListTile<bool>(
              title: const Text(
                'Yesterday Night',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              value: true,
              activeColor: Colors.purple,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          Expanded(
            child: RadioListTile<bool>(
              title: const Text(
                'Today',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              value: false,
              activeColor: Colors.purple,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      maxLines: 3,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'How did you sleep? Any observations?',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.purple, width: 2),
        ),
      ),
    );
  }
}
