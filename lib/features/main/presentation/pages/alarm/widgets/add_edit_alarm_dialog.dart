import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:snoozio/features/main/logic/alarm/custom_alarm_controller.dart';

class AddEditAlarmDialog extends StatefulWidget {
  final CustomAlarm? existingAlarm;

  const AddEditAlarmDialog({super.key, this.existingAlarm});

  @override
  State<AddEditAlarmDialog> createState() => _AddEditAlarmDialogState();
}

class _AddEditAlarmDialogState extends State<AddEditAlarmDialog> {
  late TextEditingController _nameController;
  late TimeOfDay _selectedTime;
  late Set<int> _selectedDays;
  late String _soundId;
  String? _soundPath;
  late bool _vibrate;
  bool _isLoading = false;

  final List<String> _dayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.existingAlarm != null) {
      _nameController = TextEditingController(text: widget.existingAlarm!.name);
      _selectedTime = _parseTime(widget.existingAlarm!.time);
      _selectedDays = widget.existingAlarm!.repeatDays.toSet();
      _soundId = widget.existingAlarm!.soundId;
      _soundPath = widget.existingAlarm!.soundPath;
      _vibrate = widget.existingAlarm!.vibrate;
    } else {
      _nameController = TextEditingController(text: 'Wake Up');
      _selectedTime = const TimeOfDay(hour: 7, minute: 0);
      _selectedDays = {};
      _soundId = 'default';
      _soundPath = null;
      _vibrate = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String timeString) {
    try {
      final match = RegExp(
        r'(\d+):(\d+)\s*(am|pm)',
        caseSensitive: false,
      ).firstMatch(timeString);
      if (match == null) return const TimeOfDay(hour: 7, minute: 0);

      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final isPM = match.group(3)!.toLowerCase() == 'pm';

      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 7, minute: 0);
    }
  }

  String _formatTime() {
    final hour = _selectedTime.hour == 0
        ? 12
        : _selectedTime.hour > 12
        ? _selectedTime.hour - 12
        : _selectedTime.hour;
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    final period = _selectedTime.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6C5CE7),
              onPrimary: Colors.white,
              surface: Color(0xFF1E0F33),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _selectSound() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Alarm Sound',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedVolumeHigh,
                color: Color(0xFF6C5CE7),
                size: 24,
              ),
              title: const Text(
                'Default',
                style: TextStyle(color: Colors.white),
              ),
              trailing: _soundId == 'default'
                  ? const Icon(Icons.check, color: Color(0xFF6C5CE7))
                  : null,
              onTap: () {
                setState(() {
                  _soundId = 'default';
                  _soundPath = null;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedFolder01,
                color: Color(0xFF6C5CE7),
                size: 24,
              ),
              title: const Text(
                'Pick from Device',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.audio,
                );
                if (result != null && result.files.first.path != null) {
                  setState(() {
                    _soundId = 'file';
                    _soundPath = result.files.first.path;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAlarm() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter alarm name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final alarm = CustomAlarm(
        id: widget.existingAlarm?.id ?? CustomAlarmController.generateId(),
        name: _nameController.text.trim(),
        time: _formatTime(),
        isEnabled: widget.existingAlarm?.isEnabled ?? true,
        repeatDays: _selectedDays.toList()..sort(),
        soundId: _soundId,
        soundPath: _soundPath,
        vibrate: _vibrate,
        createdAt: widget.existingAlarm?.createdAt ?? DateTime.now(),
      );

      Navigator.pop(context, alarm);
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
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNameField(),
                    const SizedBox(height: 24),
                    _buildTimeSelector(),
                    const SizedBox(height: 24),
                    _buildRepeatDays(),
                    const SizedBox(height: 24),
                    _buildSoundSelector(),
                    const SizedBox(height: 24),
                    _buildVibrateToggle(),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.existingAlarm == null ? 'Add Alarm' : 'Edit Alarm',
            style: const TextStyle(
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
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Alarm Name',
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return InkWell(
      onTap: _selectTime,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedClock03,
                  color: Color(0xFFE0AAFF),
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Time',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            Text(
              _formatTime(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatDays() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repeat',
          style: TextStyle(
            color: Color(0xFFE0AAFF),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (index) {
            final isSelected = _selectedDays.contains(index);
            return FilterChip(
              label: Text(_dayNames[index]),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedDays.add(index);
                  } else {
                    _selectedDays.remove(index);
                  }
                });
              },
              selectedColor: const Color(0xFF6C5CE7),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : const Color.fromARGB(179, 0, 0, 0),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSoundSelector() {
    return InkWell(
      onTap: _selectSound,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedVolumeHigh,
                  color: Color(0xFFE0AAFF),
                  size: 20,
                ),
                SizedBox(width: 12),
                Text(
                  'Sound',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
            Text(
              _soundId == 'default' ? 'Default' : 'Custom',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVibrateToggle() {
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
          const Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCallRinging01,
                color: Color(0xFFE0AAFF),
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'Vibrate',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          Switch(
            value: _vibrate,
            onChanged: (value) => setState(() => _vibrate = value),
            activeThumbColor: const Color(0xFF6C5CE7),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveAlarm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C5CE7),
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
            : Text(
                widget.existingAlarm == null ? 'Add Alarm' : 'Save Changes',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
