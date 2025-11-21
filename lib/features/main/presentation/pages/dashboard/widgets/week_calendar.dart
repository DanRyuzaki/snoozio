import 'package:flutter/material.dart';
import 'package:snoozio/features/main/logic/dashboard/dashboard_controller.dart';

class WeekCalendar extends StatelessWidget {
  final List<DateTime> weekDates;
  final DateTime? startDate;
  final int currentDay;
  final VoidCallback onDateTap;

  const WeekCalendar({
    super.key,
    required this.weekDates,
    required this.startDate,
    required this.currentDay,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController();

    return GestureDetector(
      onTap: onDateTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2E1A47).withValues(alpha: 0.6),
              const Color(0xFF1A0D2E).withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF9D4EDD).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9D4EDD).withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDates.map((date) {
            final isToday = controller.isToday(date);
            final isCompleted = controller.isCompleted(date, startDate);
            final isUpcoming = controller.isUpcoming(
              date,
              startDate,
              currentDay,
            );

            return _buildDayItem(
              date: date,
              isToday: isToday,
              isCompleted: isCompleted,
              isUpcoming: isUpcoming,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDayItem({
    required DateTime date,
    required bool isToday,
    required bool isCompleted,
    required bool isUpcoming,
  }) {
    Color textColor;
    Color? backgroundColor;
    FontWeight fontWeight;
    double opacity;
    Border? border;

    if (isToday) {
      textColor = Colors.white;
      backgroundColor = const Color(0xFF9D4EDD);
      fontWeight = FontWeight.bold;
      opacity = 1.0;
      border = Border.all(color: const Color(0xFFE0AAFF), width: 2);
    } else if (isCompleted) {
      textColor = Colors.white;
      backgroundColor = const Color(0xFF5A189A).withValues(alpha: 0.7);
      fontWeight = FontWeight.bold;
      opacity = 1.0;
      border = null;
    } else if (isUpcoming) {
      textColor = const Color(0xFFE0AAFF);
      backgroundColor = const Color(0xFF9D4EDD).withValues(alpha: 0.2);
      fontWeight = FontWeight.w500;
      opacity = 0.8;
      border = Border.all(
        color: const Color(0xFF9D4EDD).withValues(alpha: 0.4),
        width: 1,
      );
    } else {
      textColor = Colors.white38;
      backgroundColor = null;
      fontWeight = FontWeight.normal;
      opacity = 0.4;
      border = null;
    }

    return Container(
      width: 40,
      height: 60,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: border,
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: const Color(0xFF9D4EDD).withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getWeekdayInitial(date),
            style: TextStyle(
              color: textColor.withValues(alpha: opacity * 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date.day.toString(),
            style: TextStyle(
              color: textColor.withValues(alpha: opacity),
              fontSize: 18,
              fontWeight: fontWeight,
            ),
          ),
          if (isToday) ...[
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE0AAFF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE0AAFF).withValues(alpha: 0.6),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getWeekdayInitial(DateTime date) {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return weekdays[date.weekday - 1];
  }
}
