import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snoozio/features/diary/logic/sleep_diary_controller.dart';
import 'package:snoozio/features/diary/presentation/sleep_entry_detail_dialog.dart';
import 'package:intl/intl.dart';

class AllSleepEntriesScreen extends StatefulWidget {
  const AllSleepEntriesScreen({super.key});

  @override
  State<AllSleepEntriesScreen> createState() => _AllSleepEntriesScreenState();
}

class _AllSleepEntriesScreenState extends State<AllSleepEntriesScreen> {
  final SleepDiaryController _controller = SleepDiaryController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: const Text(
          'All Sleep Entries',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _controller.getSleepDiaryEntries(limit: 1000),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF9D4EDD)),
            );
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No sleep entries found',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final entries = snapshot.data!.docs
              .map((doc) => SleepDiaryEntry.fromFirestore(doc))
              .toList();
          final groupedEntries = _groupEntriesByDate(entries);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedEntries.length,
            itemBuilder: (context, index) {
              final date = groupedEntries.keys.elementAt(index);
              final dayEntries = groupedEntries[date]!;
              final entryCount = dayEntries.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    DateFormat('MMMM dd, yyyy').format(date),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$entryCount sleep ${entryCount == 1 ? 'entry' : 'entries'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...dayEntries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildEntryCard(entry),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<DateTime, List<SleepDiaryEntry>> _groupEntriesByDate(
    List<SleepDiaryEntry> entries,
  ) {
    final Map<DateTime, List<SleepDiaryEntry>> grouped = {};
    for (final entry in entries) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(entry);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedGrouped = Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, grouped[key]!)),
    );

    for (final entriesList in sortedGrouped.values) {
      entriesList.sort((a, b) => a.bedtime.compareTo(b.bedtime));
    }
    return sortedGrouped;
  }

  Widget _buildEntryCard(SleepDiaryEntry entry) {
    final qualityColor = Color(_controller.getColorForQuality(entry.quality));
    final emoji = _controller.getEmojiForQuality(entry.quality);
    final timeFormat = DateFormat('h:mm a');

    return GestureDetector(
      onTap: () => _showDetailDialog(entry),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF240046).withValues(alpha: 0.5),
              const Color(0xFF10002B).withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: qualityColor.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${timeFormat.format(entry.bedtime)} - ${timeFormat.format(entry.wakeTime)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.sleepEfficiency.toStringAsFixed(0)}% efficiency',
                    style: TextStyle(color: qualityColor, fontSize: 14),
                  ),
                ],
              ),
            ),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: Colors.white60,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailDialog(SleepDiaryEntry entry) {
    showDialog(
      context: context,
      builder: (context) =>
          SleepEntryDetailDialog(entry: entry, controller: _controller),
    );
  }
}
