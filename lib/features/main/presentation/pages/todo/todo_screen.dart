import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:snoozio/core/helper/activity_reminder_helper.dart';
import 'package:snoozio/features/completion/program_complete_screen.dart';
import 'package:snoozio/features/main/logic/todo/todo_controller.dart';
import 'package:snoozio/features/main/logic/todo/day_progression_controller.dart';
import 'dart:math';
import 'dart:async';
import 'package:snoozio/core/notification/notification_event_bus.dart';

class _ActivityWithIndex {
  final ActivityModel activity;
  final int index;

  _ActivityWithIndex(this.activity, this.index);
}

class ToDoSection extends StatelessWidget {
  const ToDoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadInitialData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingState();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return ErrorState(
            title: 'Error Loading Data',
            message: '${snapshot.error}',
          );
        }

        final data = snapshot.data!;
        final currentDay = data['currentDay'] as int;

        if (currentDay > 30) {
          return const ProgramCompletionScreen();
        }

        if (currentDay == 0) {
          return const DayZeroOrientationScreen();
        }

        final carePlan = data['carePlan'] as String;
        final currentDayDate = data['currentDayDate'] as DateTime?;

        return FutureBuilder<bool>(
          future: _isDayReady(currentDayDate),
          builder: (context, readySnapshot) {
            if (!readySnapshot.hasData) {
              return const LoadingState();
            }

            if (!readySnapshot.data!) {
              return DayCountdownScreen(
                currentDay: currentDay,
                currentDayDate: currentDayDate,
              );
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('care_plans')
                  .doc(carePlan)
                  .collection('v1')
                  .doc('day_$currentDay')
                  .snapshots(),
              builder: (context, daySnapshot) {
                if (daySnapshot.hasError) {
                  return ErrorState(
                    title: 'Error Loading Care Plan',
                    message: 'Error: ${daySnapshot.error}',
                  );
                }

                if (!daySnapshot.hasData) {
                  return const LoadingState();
                }

                if (!daySnapshot.data!.exists) {
                  return ErrorState(
                    title: 'Day Not Found',
                    message: 'Contact us through Help Center to fix this issue',
                  );
                }

                try {
                  final dayModel = DayModel.fromFirestore(daySnapshot.data!);
                  return ToDoListScreen(
                    dayModel: dayModel,
                    currentDay: currentDay,
                  );
                } catch (e) {
                  return FormatErrorState(errorDetails: e.toString());
                }
              },
            );
          },
        );
      },
    );
  }
}

Future<Map<String, dynamic>> _loadInitialData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('No user logged in');

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  if (!userDoc.exists) throw Exception('User document not found');

  final data = userDoc.data()!;
  final carePlan = await ToDoLogic.getUserCarePlan();
  final currentDay = data['currentDay'] ?? 0;
  final currentDayDate = (data['currentDayDate'] as Timestamp?)?.toDate();

  return {
    'carePlan': carePlan,
    'currentDay': currentDay,
    'currentDayDate': currentDayDate,
  };
}

Future<bool> _isDayReady(DateTime? currentDayDate) async {
  if (currentDayDate == null) return false;

  final now = DateTime.now();
  final todayMidnight = DateTime(now.year, now.month, now.day);
  final dayDateMidnight = DateTime(
    currentDayDate.year,
    currentDayDate.month,
    currentDayDate.day,
  );

  return !todayMidnight.isBefore(dayDateMidnight);
}

class DayZeroOrientationScreen extends StatefulWidget {
  const DayZeroOrientationScreen({super.key});

  @override
  State<DayZeroOrientationScreen> createState() =>
      _DayZeroOrientationScreenState();
}

class _DayZeroOrientationScreenState extends State<DayZeroOrientationScreen> {
  bool _isLoading = false;

  Future<void> _startProgram() async {
    setState(() => _isLoading = true);

    try {
      await DayProgressionController.startProgram();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Congratulations! Your journey begins tomorrow!'),
          backgroundColor: Color(0xFF27AE60),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                  const Color(0xFF4834D4).withValues(alpha: 0.2),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFE0AAFF).withValues(alpha: 0.4),
                width: 3,
              ),
            ),
            child: const Center(
              child: Text('👋', style: TextStyle(fontSize: 64)),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Welcome to Snoozio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your 30-day sleep improvement journey',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildInfoCard(
            icon: HugeIcons.strokeRoundedCalendar01,
            title: '30 Days of Better Sleep',
            description:
                'Follow personalized daily activities designed to improve your sleep quality.',
            color: const Color(0xFF6C5CE7),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: HugeIcons.strokeRoundedAlarmClock,
            title: 'Daily Reminders',
            description:
                'Get notified for each activity at the right time to build healthy habits.',
            color: const Color(0xFF9D4EDD),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: HugeIcons.strokeRoundedMoon02,
            title: 'Track Your Progress',
            description: 'Log your sleep diary and see improvements over time.',
            color: const Color(0xFF7209B7),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                  const Color(0xFF4834D4).withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE0AAFF).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  size: 48,
                  color: Color(0xFFE0AAFF),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ready to Begin?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your Day 1 will start tomorrow, giving you time to prepare for a fresh start.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _startProgram,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
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
                            'Start Tomorrow',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required List<List<dynamic>> icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: HugeIcon(icon: icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.4,
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

class DayCountdownScreen extends StatelessWidget {
  final int currentDay;
  final DateTime? currentDayDate;

  const DayCountdownScreen({
    super.key,
    required this.currentDay,
    this.currentDayDate,
  });

  int _getDaysUntilDayStarts() {
    if (currentDayDate == null) return 0;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final dayDateMidnight = DateTime(
      currentDayDate!.year,
      currentDayDate!.month,
      currentDayDate!.day,
    );

    final difference = dayDateMidnight.difference(todayMidnight).inDays;
    return difference > 0 ? difference : 0;
  }

  @override
  Widget build(BuildContext context) {
    final daysUntil = _getDaysUntilDayStarts();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
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
                child: Text('⏳', style: TextStyle(fontSize: 64)),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Day $currentDay',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Starts in $daysUntil ${daysUntil == 1 ? 'day' : 'days'}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Take this time to prepare mentally for your sleep journey. Day $currentDay activities will be available soon!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (currentDayDate != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar01,
                            color: Color(0xFFE0AAFF),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Starts on: ${_formatDate(currentDayDate!)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class ToDoListScreen extends StatefulWidget {
  final DayModel dayModel;
  final int currentDay;

  const ToDoListScreen({
    super.key,
    required this.dayModel,
    required this.currentDay,
  });

  @override
  State<ToDoListScreen> createState() => _ToDoListScreenState();
}

class _ToDoListScreenState extends State<ToDoListScreen> {
  bool _isProcessing = false;
  StreamSubscription<NotificationActionEvent>? _notifSub;

  @override
  void initState() {
    super.initState();
    _notifSub = NotificationEventBus.instance.stream.listen((event) async {
      if (event.actionId == 'mark_done' && event.activityId != null) {
        try {
          await ToDoLogic.updateActivityStatus(
            activityId: event.activityId!,
            status: 'done',
            completedAt: Timestamp.now(),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Activity marked as complete via notification'),
                backgroundColor: Color(0xFF27AE60),
              ),
            );
            setState(() {});
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Future<bool> _canProgressToNextDay() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return false;

    final data = userDoc.data() ?? {};
    final currentDayDate = (data['currentDayDate'] as Timestamp?)?.toDate();

    if (currentDayDate == null) return false;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final dayDateMidnight = DateTime(
      currentDayDate.year,
      currentDayDate.month,
      currentDayDate.day,
    );

    if (todayMidnight.isBefore(dayDateMidnight)) {
      return false;
    }

    final carePlan = await ToDoLogic.getUserCarePlan();
    return await ToDoLogic.canProgressToNextDay(carePlan, widget.currentDay);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DayHeader(
            dayNumber: widget.dayModel.formattedDay,
            activityCount: widget.dayModel.activities.length,
          ),
          const SizedBox(height: 16),
          FutureBuilder<bool>(
            future: _canProgressToNextDay(),
            builder: (context, snapshot) {
              final canProgress = snapshot.data ?? false;
              return _buildProgressionButtons(canProgress);
            },
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildActivitySections()),
        ],
      ),
    );
  }

  Widget _buildProgressionButtons(bool canProgress) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: canProgress && !_isProcessing
                  ? _handleMoveToNextDay
                  : null,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: canProgress
                    ? const Color(0xFF27AE60)
                    : Colors.white.withValues(alpha: 0.3),
              ),
              label: Text(
                'Day ${widget.currentDay + 1}',
                style: TextStyle(
                  color: canProgress
                      ? const Color(0xFF27AE60)
                      : Colors.white.withValues(alpha: 0.3),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: _isProcessing ? null : _handleRestartDay,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                size: 16,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              label: Text(
                'Restart',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMoveToNextDay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E0F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Move to Next Day?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you ready to move on to Day ${widget.currentDay + 1}? You can review your current day progress before proceeding.',
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
              backgroundColor: const Color(0xFF27AE60),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      await DayProgressionController.advanceToNextDay();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎉 Congratulations! Welcome to Day ${widget.currentDay + 1}!',
          ),
          backgroundColor: const Color(0xFF27AE60),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRestartDay() async {
    final random = Random();
    final num1 = random.nextInt(10) + 1;
    final num2 = random.nextInt(10) + 1;
    final correctAnswer = num1 + num2;

    final mathAnswer = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MathVerificationDialog(num1: num1, num2: num2),
    );

    if (mathAnswer == null || mathAnswer != correctAnswer) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Incorrect answer. Please try again.'),
            backgroundColor: Color(0xFFE74C3C),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E0F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Restart This Day?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will reset all activities for today and reschedule this day for tomorrow. Your progress will be cleared.',
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
            child: const Text('Restart', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      await DayProgressionController.restartCurrentDay();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Day restarted! Activities will be available tomorrow.',
          ),
          backgroundColor: Color(0xFFE74C3C),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildActivitySections() {
    return FutureBuilder<Map<ActivitySection, List<_ActivityWithIndex>>>(
      future: _organizeActivitiesBySection(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sections = snapshot.data!;

        return ListView(
          children: [
            _buildSection(
              ActivitySection.current,
              sections[ActivitySection.current] ?? [],
            ),
            _buildSection(
              ActivitySection.upcoming,
              sections[ActivitySection.upcoming] ?? [],
            ),
            _buildSection(
              ActivitySection.completed,
              sections[ActivitySection.completed] ?? [],
            ),
            _buildSection(
              ActivitySection.missed,
              sections[ActivitySection.missed] ?? [],
            ),
            _buildSection(
              ActivitySection.disabled,
              sections[ActivitySection.disabled] ?? [],
            ),
            const SizedBox(height: 100),
          ],
        );
      },
    );
  }

  Widget _buildSection(
    ActivitySection section,
    List<_ActivityWithIndex> activities,
  ) {
    if (activities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(section),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedInboxUnread,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No activities in this section',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(section),
          const SizedBox(height: 12),
          ...activities.map(
            (item) => _buildActivityItem(item.activity, item.index),
          ),
        ],
      ),
    );
  }

  Future<Map<ActivitySection, List<_ActivityWithIndex>>>
  _organizeActivitiesBySection() async {
    final Map<ActivitySection, List<_ActivityWithIndex>> organized = {
      ActivitySection.current: [],
      ActivitySection.upcoming: [],
      ActivitySection.completed: [],
      ActivitySection.missed: [],
      ActivitySection.disabled: [],
    };

    for (int i = 0; i < widget.dayModel.activities.length; i++) {
      final activity = widget.dayModel.activities[i];
      final activityId = ToDoLogic.getActivityId(widget.dayModel.dayId, i);

      final statusDoc = await ToDoLogic.getActivityStatusStream(
        activityId,
      ).first;
      final status = ActivityStatus.fromFirestore(statusDoc);

      final isCurrentActivity = _isCurrentActivity(activity, i);
      final section = ToDoLogic.getActivitySection(
        status: status.status,
        timeString: activity.time,
        isCurrentActivity: isCurrentActivity,
        notificationEnabled: status.notificationEnabled,
      );

      organized[section]!.add(_ActivityWithIndex(activity, i));
    }

    return organized;
  }

  Widget _buildActivityItem(ActivityModel activity, int index) {
    final activityId = ToDoLogic.getActivityId(widget.dayModel.dayId, index);

    return StreamBuilder<DocumentSnapshot>(
      stream: ToDoLogic.getActivityStatusStream(activityId),
      builder: (context, statusSnapshot) {
        final status = ActivityStatus.fromFirestore(statusSnapshot.data);
        final isCurrentActivity = _isCurrentActivity(activity, index);
        final section = ToDoLogic.getActivitySection(
          status: status.status,
          timeString: activity.time,
          isCurrentActivity: isCurrentActivity,
        );

        return ActivityCard(
          activity: activity,
          activityId: activityId,
          status: status,
          section: section,
          onStatusUpdate: (newStatus) =>
              _handleStatusUpdate(activityId, newStatus),
          onToggleNotification: (enabled) =>
              _handleToggleNotification(activityId, enabled),
        );
      },
    );
  }

  bool _isCurrentActivity(ActivityModel activity, int index) {
    final now = DateTime.now();

    try {
      final parts = activity.time.split(':');
      if (parts.length != 2) return false;

      final hour = int.parse(parts[0].trim());
      final minute = int.parse(parts[1].split(' ')[0].trim());
      final isPm = activity.time.toLowerCase().contains('pm');

      var scheduledHour = hour;
      if (isPm && hour != 12) {
        scheduledHour += 12;
      } else if (!isPm && hour == 12) {
        scheduledHour = 0;
      }

      final scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        scheduledHour,
        minute,
      );

      final difference = now.difference(scheduled).inMinutes;
      return difference >= -60 && difference <= 60;
    } catch (e) {
      return false;
    }
  }

  Widget _buildSectionHeader(ActivitySection section) {
    String title;
    List<List<dynamic>> icon;
    Color color;

    switch (section) {
      case ActivitySection.current:
        title = 'Current Activity';
        icon = HugeIcons.strokeRoundedAlarmClock;
        color = const Color(0xFF6C5CE7);
        break;
      case ActivitySection.upcoming:
        title = 'Upcoming Activities';
        icon = HugeIcons.strokeRoundedClock03;
        color = const Color(0xFF4A90E2);
        break;
      case ActivitySection.completed:
        title = 'Completed Activities';
        icon = HugeIcons.strokeRoundedCheckmarkCircle02;
        color = const Color(0xFF27AE60);
        break;
      case ActivitySection.missed:
        title = 'Missed Activities';
        icon = HugeIcons.strokeRoundedAlertCircle;
        color = const Color(0xFFE74C3C);
        break;
      case ActivitySection.disabled:
        title = 'Disabled Reminders';
        icon = HugeIcons.strokeRoundedNotificationOff02;
        color = const Color(0xFF95A5A6);
        break;
    }

    return Row(
      children: [
        HugeIcon(icon: icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _handleStatusUpdate(String activityId, String newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmationDialog(newStatus),
    );

    if (confirmed != true) return;

    await ToDoLogic.updateActivityStatus(
      activityId: activityId,
      status: newStatus,
      completedAt: newStatus == 'done' || newStatus == 'skipped'
          ? Timestamp.now()
          : null,
      missedAt: newStatus == 'missed' ? Timestamp.now() : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'done'
                ? 'Activity marked as complete! 🎉'
                : 'Activity skipped',
          ),
          backgroundColor: const Color(0xFF6C5CE7),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildConfirmationDialog(String status) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E0F33),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        status == 'done' ? 'Complete Activity?' : 'Skip Activity?',
        style: const TextStyle(color: Colors.white),
      ),
      content: Text(
        status == 'done'
            ? 'Mark this activity as completed?'
            : 'Mark this activity as skipped?',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
          ),
          child: const Text(
            'Confirm',
            style: TextStyle(color: Color(0xFFFFFFFF)),
          ),
        ),
      ],
    );
  }

  Future<void> _handleToggleNotification(
    String activityId,
    bool enabled,
  ) async {
    try {
      final activityIndex = int.parse(activityId.split('_').last);
      final activity = widget.dayModel.activities[activityIndex];

      final result = await ActivityReminderHelper.toggleNotification(
        activityId: activityId,
        enabled: enabled,
        activityName: activity.activity,
        time: activity.time,
        dayNumber: widget.currentDay,
      );

      if (!mounted) return;

      switch (result) {
        case 'success':
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    enabled
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      enabled
                          ? 'Reminder enabled for ${activity.time}'
                          : 'Reminder disabled',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF6C5CE7),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          break;

        case 'time_passed':
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '⏰ Cannot enable reminder\n${activity.time} has already passed today',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFE67E22),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Got it',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
          break;

        case 'error':
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text('❌ Failed to update reminder')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _MathVerificationDialog extends StatefulWidget {
  final int num1;
  final int num2;

  const _MathVerificationDialog({required this.num1, required this.num2});

  @override
  State<_MathVerificationDialog> createState() =>
      _MathVerificationDialogState();
}

class _MathVerificationDialogState extends State<_MathVerificationDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E0F33),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSecurityCheck,
            color: Color(0xFFE0AAFF),
            size: 24,
          ),
          SizedBox(width: 12),
          Text(
            'Verify You\'re Human',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Please solve this simple math problem:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              '${widget.num1} + ${widget.num2} = ?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: 'Your answer',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF6C5CE7),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            final answer = int.tryParse(_controller.text);
            Navigator.pop(context, answer);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
          ),
          child: const Text('Submit', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final String activityId;
  final ActivityStatus status;
  final ActivitySection section;
  final Function(String) onStatusUpdate;
  final Function(bool) onToggleNotification;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.activityId,
    required this.status,
    required this.section,
    required this.onStatusUpdate,
    required this.onToggleNotification,
  });

  @override
  Widget build(BuildContext context) {
    final isInteractive =
        section == ActivitySection.current ||
        section == ActivitySection.upcoming;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor(),
          width: section == ActivitySection.current ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          if (isInteractive)
            Switch(
              value: status.notificationEnabled,
              onChanged: (value) => onToggleNotification(value),
              activeThumbColor: const Color(0xFF6C5CE7),
            )
          else
            const SizedBox(width: 48),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.activity,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    decoration: _getTextDecoration(),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedClock03,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activity.time,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (section == ActivitySection.current) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: Color(0xFF27AE60),
                size: 28,
              ),
              onPressed: () => onStatusUpdate('done'),
            ),
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCancelCircle,
                color: Color(0xFFE74C3C),
                size: 28,
              ),
              onPressed: () => onStatusUpdate('skipped'),
            ),
          ],

          if (section == ActivitySection.completed)
            HugeIcon(
              icon: status.status == 'done'
                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                  : HugeIcons.strokeRoundedCancelCircle,
              color: status.status == 'done'
                  ? const Color(0xFF27AE60)
                  : const Color(0xFFE74C3C),
              size: 24,
            ),

          if (section == ActivitySection.missed)
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle,
              color: Color(0xFFE74C3C),
              size: 24,
            ),

          if (section == ActivitySection.disabled)
            const HugeIcon(
              icon: HugeIcons.strokeRoundedNotificationOff02,
              color: Color(0xFF95A5A6),
              size: 24,
            ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (section) {
      case ActivitySection.current:
        return Colors.white.withValues(alpha: 0.15);
      case ActivitySection.upcoming:
        return Colors.white.withValues(alpha: 0.1);
      case ActivitySection.completed:
        return Colors.green.withValues(alpha: 0.1);
      case ActivitySection.missed:
        return Colors.red.withValues(alpha: 0.1);
      case ActivitySection.disabled:
        return Colors.grey.withValues(alpha: 0.1);
    }
  }

  Color _getBorderColor() {
    switch (section) {
      case ActivitySection.current:
        return const Color(0xFF6C5CE7);
      case ActivitySection.upcoming:
        return Colors.white.withValues(alpha: 0.2);
      case ActivitySection.completed:
        return const Color(0xFF27AE60).withValues(alpha: 0.3);
      case ActivitySection.missed:
        return const Color(0xFFE74C3C).withValues(alpha: 0.3);
      case ActivitySection.disabled:
        return const Color(0xFF95A5A6).withValues(alpha: 0.3);
    }
  }

  TextDecoration? _getTextDecoration() {
    if (section == ActivitySection.completed ||
        section == ActivitySection.missed) {
      return TextDecoration.lineThrough;
    }
    return null;
  }
}

class DayHeader extends StatelessWidget {
  final String dayNumber;
  final int activityCount;

  const DayHeader({
    super.key,
    required this.dayNumber,
    required this.activityCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dayNumber,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$activityCount reminders for today',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String title;
  final String message;

  const ErrorState({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class FormatErrorState extends StatelessWidget {
  final String errorDetails;

  const FormatErrorState({super.key, required this.errorDetails});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlertDiamond,
              size: 64,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error 222',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Care plan format is not met',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Expected format: day_[number]',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'Details: $errorDetails',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
