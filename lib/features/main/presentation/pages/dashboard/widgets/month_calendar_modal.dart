import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:snoozio/features/main/logic/dashboard/dashboard_controller.dart';

class MonthCalendarModal extends StatelessWidget {
  final DateTime startDate;
  final DateTime programEndDate;
  final int currentDay;

  const MonthCalendarModal({
    super.key,
    required this.startDate,
    required this.programEndDate,
    required this.currentDay,
  });

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Sleep Journey',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Day $currentDay of 30',
                      style: TextStyle(
                        color: const Color(0xFF9D4EDD).withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    color: Color(0xFFE0AAFF),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: _buildMonthGrids(controller)),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A0D2E).withValues(alpha: 0.5),
                  const Color(0xFF0D0A1A).withValues(alpha: 0.9),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF9D4EDD).withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Today', const Color(0xFF9D4EDD)),
                _buildLegendItem('Completed', const Color(0xFF5A189A)),
                _buildLegendItem(
                  'Upcoming',
                  const Color(0xFF9D4EDD).withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMonthGrids(DashboardController controller) {
    final months = <Widget>[];
    DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);

    final endDate = programEndDate;
    final lastMonth = DateTime(endDate.year, endDate.month, 1);

    while (currentMonth.isBefore(lastMonth) ||
        (currentMonth.year == lastMonth.year &&
            currentMonth.month == lastMonth.month)) {
      months.add(_buildMonthGrid(currentMonth, controller));
      months.add(const SizedBox(height: 24));
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    return months;
  }

  Widget _buildMonthGrid(DateTime month, DashboardController controller) {
    final monthName = _getMonthName(month.month);
    final year = month.year;
    final daysInMonth = DateTime(year, month.month + 1, 0).day;
    final firstWeekday = DateTime(year, month.month, 1).weekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$monthName $year',
          style: const TextStyle(
            color: Color(0xFFE0AAFF),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
            return SizedBox(
              width: 40,
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    color: const Color(0xFF9D4EDD).withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 0,
          runSpacing: 8,
          children: List.generate(42, (index) {
            final dayNumber = index - (firstWeekday - 1) + 1;

            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox(width: 40, height: 40);
            }

            final date = DateTime(year, month.month, dayNumber);
            final isToday = controller.isToday(date);
            final isCompleted = controller.isCompleted(date, startDate);
            final isUpcoming = controller.isUpcoming(
              date,
              startDate,
              currentDay,
            );
            final dayNum = controller.getDayNumber(date, startDate);

            return _buildDayCell(
              day: dayNumber,
              dayNum: dayNum,
              isToday: isToday,
              isCompleted: isCompleted,
              isUpcoming: isUpcoming,
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDayCell({
    required int day,
    required int? dayNum,
    required bool isToday,
    required bool isCompleted,
    required bool isUpcoming,
  }) {
    Color? backgroundColor;
    Color textColor;
    FontWeight fontWeight;
    Border? border;

    if (isToday) {
      backgroundColor = const Color(0xFF9D4EDD);
      textColor = Colors.white;
      fontWeight = FontWeight.bold;
      border = Border.all(color: const Color(0xFFE0AAFF), width: 2);
    } else if (isCompleted) {
      backgroundColor = const Color(0xFF5A189A).withValues(alpha: 0.7);
      textColor = Colors.white;
      fontWeight = FontWeight.bold;
      border = null;
    } else if (isUpcoming) {
      backgroundColor = const Color(0xFF9D4EDD).withValues(alpha: 0.2);
      textColor = const Color(0xFFE0AAFF);
      fontWeight = FontWeight.w500;
      border = Border.all(
        color: const Color(0xFF9D4EDD).withValues(alpha: 0.4),
        width: 1,
      );
    } else {
      backgroundColor = null;
      textColor = Colors.white24;
      fontWeight = FontWeight.normal;
      border = null;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: border,
      ),
      child: Center(
        child: Text(
          day.toString(),
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: label == 'Today'
                ? Border.all(color: const Color(0xFFE0AAFF), width: 1.5)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
