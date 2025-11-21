import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snoozio/features/main/logic/dashboard/dashboard_controller.dart';
import 'package:snoozio/features/diary/logic/sleep_diary_controller.dart';
import 'package:snoozio/features/main/presentation/pages/dashboard/widgets/week_calendar.dart';
import 'package:snoozio/features/main/presentation/pages/dashboard/widgets/month_calendar_modal.dart';
import 'package:snoozio/features/main/presentation/pages/dashboard/widgets/daily_quote_card.dart';
import 'package:snoozio/features/main/presentation/pages/dashboard/widgets/sleep_diary_card.dart';
import 'package:snoozio/features/diary/presentation/add_sleep_entry_dialog.dart';
import 'package:snoozio/features/diary/presentation/all_sleep_entries_screen.dart';
import 'package:restart_app/restart_app.dart';

class DashboardSection extends StatefulWidget {
  final VoidCallback? onNavigateToTodo;

  const DashboardSection({super.key, this.onNavigateToTodo});

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  final DashboardController _dashboardController = DashboardController();
  final SleepDiaryController _sleepDiaryController = SleepDiaryController();

  void _showMonthCalendar(
    BuildContext context,
    DateTime startDate,
    DateTime programEndDate,
    int currentDay,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MonthCalendarModal(
        startDate: startDate,
        programEndDate: programEndDate,
        currentDay: currentDay,
      ),
    );
  }

  void _showAddSleepEntry() {
    showDialog(
      context: context,
      builder: (context) => const AddSleepEntryDialog(),
    ).then((result) {
      if (result == true && mounted) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _dashboardController.getUserDataStream(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: const Color(0xFF9D4EDD)),
          );
        }

        final currentDay = _dashboardController.getCurrentDay(
          userSnapshot.data!,
        );
        final startDate = _dashboardController.getCreatedAt(userSnapshot.data!);
        final programEndDate = _dashboardController.getProgramEndDate(
          userSnapshot.data!,
        );
        final weekDates = _dashboardController.getWeekDates(DateTime.now());
        final assessment = userSnapshot.data!.get('assessment') ?? 0;
        final isNormalUser = assessment == 0;

        if (startDate == null || programEndDate == null) {
          return const Center(
            child: Text(
              'User data not properly initialized',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WeekCalendar(
                weekDates: weekDates,
                startDate: startDate,
                currentDay: currentDay,
                onDateTap: () => _showMonthCalendar(
                  context,
                  startDate,
                  programEndDate,
                  currentDay,
                ),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: Container(
                    width: 290,
                    height: 290,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.purple.withValues(alpha: 0.35),
                          Colors.blue.withValues(alpha: 0.25),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isNormalUser ? 'Snoozio' : 'Day $currentDay',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isNormalUser
                              ? 'Your Sleep Companion App'
                              : 'of your Snoozio journey',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        isNormalUser
                            ? TextButton(
                                onPressed: () async {
                                  await _dashboardController
                                      .updateAssessmentToNormal();
                                  Restart.restartApp();
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.12,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 0.8,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Take the assessment',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              )
                            : TextButton.icon(
                                onPressed: widget.onNavigateToTodo,
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedCalendar01,
                                  color: Color(0xFFE0AAFF),
                                  size: 18,
                                ),
                                label: const Text(
                                  'View Tasks',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.12,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 0.8,
                                    ),
                                  ),
                                ),
                              ),

                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              FutureBuilder<String>(
                future: _dashboardController.getDailyQuote(currentDay),
                builder: (context, quoteSnapshot) {
                  return DailyQuoteCard(
                    quote: quoteSnapshot.data ?? 'Loading...',
                  );
                },
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF5A189A,
                            ).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const HugeIcon(
                            icon: HugeIcons.strokeRoundedMoon02,
                            color: Color(0xFFE0AAFF),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Sleep Diary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _showAddSleepEntry,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedAdd01,
                        color: Color(0xFF9D4EDD),
                        size: 18,
                      ),
                      label: Text(
                        'Add',
                        style: TextStyle(
                          color: const Color(0xFF9D4EDD),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              StreamBuilder<QuerySnapshot>(
                stream: _sleepDiaryController.getSleepDiaryEntries(limit: 7),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildEmptySleepDiary(),
                    );
                  }

                  final docs = snapshot.data!.docs.toList();

                  return Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final entry = SleepDiaryEntry.fromFirestore(
                              docs[index],
                            );
                            return SleepDiaryCard(
                              entry: entry,
                              controller: _sleepDiaryController,
                            );
                          },
                        ),
                      ),
                      if (docs.length >= 7)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AllSleepEntriesScreen(),
                              ),
                            ),
                            child: const Text(
                              'View All Entries',
                              style: TextStyle(
                                color: Color(0xFF9D4EDD),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptySleepDiary() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF240046).withValues(alpha: 0.4),
            const Color(0xFF10002B).withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF5A189A).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF5A189A).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedMoonCloudMidRain,
              size: 48,
              color: Color(0xFFE0AAFF),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No sleep entries yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start tracking your sleep for better insights',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showAddSleepEntry,
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 20,
              color: Colors.white,
            ),
            label: const Text(
              'Add Your First Entry',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7209B7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
