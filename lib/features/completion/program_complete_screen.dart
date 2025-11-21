import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class ProgramCompletionScreen extends StatefulWidget {
  final int totalDays;

  const ProgramCompletionScreen({super.key, this.totalDays = 30});

  @override
  State<ProgramCompletionScreen> createState() =>
      _ProgramCompletionScreenState();
}

class _ProgramCompletionScreenState extends State<ProgramCompletionScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _fadeController;
  late ConfettiController _blastConfettiController;
  int _currentRating = 0;
  final bool _isSubmittingRating = false;
  Map<String, dynamic> _userStats = {};
  List<DayPerformance> _dayPerformances = [];
  bool _isLoadingStats = true;
  String _completeId = '';

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..forward();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _blastConfettiController = ConfettiController(
      duration: const Duration(seconds: 15),
    );

    _loadProgramStats();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _fadeController.dispose();
    _blastConfettiController.dispose();
    super.dispose();
  }

  Future<void> _loadProgramStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final programStartDate = (userDoc['programStartDate'] as Timestamp?)
          ?.toDate();
      final assessment = userDoc['assessment'] ?? 4;
      final carePlan = _getCarePlanName(assessment);
      final displayName = userDoc['displayName'] ?? 'Sleep Champion';
      final email = userDoc['email'] ?? user.email ?? '';

      final dayPerformances = <DayPerformance>[];
      int totalCompleted = 0;
      int totalSkipped = 0;
      int totalMissed = 0;
      int totalPending = 0;
      int totalActivities = 0;

      for (int day = 1; day <= widget.totalDays; day++) {
        final dayDoc = await FirebaseFirestore.instance
            .collection('care_plans')
            .doc(carePlan)
            .collection('v1')
            .doc('day_$day')
            .get();

        if (!dayDoc.exists) continue;

        final activities = dayDoc['activities'] as List<dynamic>? ?? [];
        final totalActivitiesForDay = activities.length;
        totalActivities += totalActivitiesForDay;

        int dayCompleted = 0;
        int daySkipped = 0;
        int dayMissed = 0;
        int dayPending = 0;

        for (int i = 0; i < totalActivitiesForDay; i++) {
          final activityId = 'day_${day}_$i';
          final statusDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('activity_status')
              .doc(activityId)
              .get();

          if (statusDoc.exists) {
            final status = statusDoc['status'] as String;
            switch (status) {
              case 'done':
                dayCompleted++;
                totalCompleted++;
                break;
              case 'skipped':
                daySkipped++;
                totalSkipped++;
                break;
              case 'missed':
                dayMissed++;
                totalMissed++;
                break;
              default:
                dayPending++;
                totalPending++;
            }
          } else {
            dayMissed++;
            totalMissed++;
          }
        }

        final performance = totalActivitiesForDay > 0
            ? ((dayCompleted + daySkipped) / totalActivitiesForDay * 100)
                  .toInt()
            : 0;

        dayPerformances.add(
          DayPerformance(
            day: day,
            completed: dayCompleted,
            skipped: daySkipped,
            missed: dayMissed,
            pending: dayPending,
            performanceScore: performance,
            date:
                programStartDate?.add(Duration(days: day - 1)) ??
                DateTime.now(),
          ),
        );
      }

      final overallScore = totalActivities > 0
          ? ((totalCompleted + totalSkipped) / totalActivities * 100).toInt()
          : 0;

      final programEndDate = DateTime.now();
      final completeId =
          '${user.uid}_${assessment}_${overallScore}_${programStartDate?.toIso8601String().split('T')[0] ?? 'N/A'}_${programEndDate.toIso8601String().split('T')[0]}';

      setState(() {
        _completeId = completeId;
        _userStats = {
          'carePlan': carePlan,
          'programStartDate': programStartDate,
          'displayName': displayName,
          'email': email,
          'totalCompleted': totalCompleted,
          'totalSkipped': totalSkipped,
          'totalMissed': totalMissed,
          'totalPending': totalPending,
          'overallScore': overallScore,
        };
        _dayPerformances = dayPerformances;
        _isLoadingStats = false;
      });

      _blastConfettiController.play();
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  String _getCarePlanName(int assessment) {
    switch (assessment) {
      case 1:
        return 'mild';
      case 2:
        return 'moderate';
      case 3:
        return 'severe';
      case 0:
        return 'normal';
      default:
        return 'unassigned';
    }
  }

  Color _getPerformanceColor(int score) {
    if (score >= 80) return const Color(0xFF27AE60);
    if (score >= 60) return const Color(0xFFFFD700);
    if (score >= 40) return const Color(0xFFFF9800);
    return const Color(0xFFE74C3C);
  }

  Future<Uint8List> _generatePDF() async {
    final pdf = pw.Document();

    final deepPurple = PdfColor.fromHex('#1A0D2E');
    final lightPurple = PdfColor.fromHex('#6C5CE7');
    final accentPurple = PdfColor.fromHex('#9D4EDD');
    final gold = PdfColor.fromHex('#FFD700');
    final textWhite = PdfColor.fromHex('#FFFFFF');
    final textGray = PdfColor.fromHex('#B0B0B0');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Container(
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    begin: pw.Alignment.topCenter,
                    end: pw.Alignment.bottomCenter,
                    colors: [deepPurple, PdfColor.fromHex('#0D0A1A')],
                  ),
                ),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(40),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(height: 20),
                    pw.Container(
                      width: 100,
                      height: 4,
                      decoration: pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [lightPurple, accentPurple, gold],
                        ),
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                    ),
                    pw.SizedBox(height: 30),
                    pw.Text(
                      'CERTIFICATE',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: accentPurple,
                        letterSpacing: 4,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'OF COMPLETION',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.normal,
                        color: textGray,
                        letterSpacing: 3,
                      ),
                    ),
                    pw.SizedBox(height: 30),
                    pw.Text(
                      'Snoozio Culminator',
                      style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        color: accentPurple,
                        letterSpacing: 4,
                      ),
                    ),
                    pw.SizedBox(height: 30),
                    pw.Text(
                      'This is proudly presented to',
                      style: pw.TextStyle(fontSize: 12, color: textGray),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Container(
                      padding: pw.EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(color: accentPurple, width: 2),
                          bottom: pw.BorderSide(color: accentPurple, width: 2),
                        ),
                      ),
                      child: pw.Text(
                        _userStats['displayName']?.toString() ??
                            'Sleep Champion',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: gold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      _userStats['email']?.toString() ?? '',
                      style: pw.TextStyle(fontSize: 10, color: textGray),
                    ),
                    pw.SizedBox(height: 30),
                    pw.Container(
                      width: 400,
                      child: pw.Text(
                        'For successfully completing the 30-day Snoozio Sleep Improvement Program and taking meaningful steps towards better sleep health',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: textWhite,
                          height: 1.5,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(height: 35),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPDFStatBox(
                          'Care Plan',
                          _userStats['carePlan']?.toString().toLowerCase() ??
                              'N/A',
                          lightPurple,
                          textWhite,
                        ),
                        _buildPDFStatBox(
                          'Overall Score',
                          '${_userStats['overallScore']}%',
                          gold,
                          deepPurple,
                        ),
                        _buildPDFStatBox(
                          'Days Completed',
                          '30',
                          accentPurple,
                          textWhite,
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 30),
                    pw.Container(
                      padding: pw.EdgeInsets.all(20),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: accentPurple, width: 1),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            '30-Day Performance Timeline',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: accentPurple,
                            ),
                          ),
                          pw.SizedBox(height: 15),
                          pw.Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _dayPerformances.map((day) {
                              return pw.Container(
                                width: 25,
                                height: 25,
                                decoration: pw.BoxDecoration(
                                  color: _getPDFPerformanceColor(
                                    day.performanceScore,
                                  ),
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Center(
                                  child: pw.Text(
                                    '${day.day}',
                                    style: pw.TextStyle(
                                      color: textWhite,
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          pw.SizedBox(height: 15),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              _buildPDFLegend(
                                'Excellent 80%+',
                                PdfColors.green,
                                textWhite,
                              ),
                              pw.SizedBox(width: 15),
                              _buildPDFLegend(
                                'Good 60%+',
                                PdfColors.yellow,
                                textWhite,
                              ),
                              pw.SizedBox(width: 15),
                              _buildPDFLegend(
                                'Fair 40%+',
                                PdfColors.orange,
                                textWhite,
                              ),
                              pw.SizedBox(width: 15),
                              _buildPDFLegend(
                                'Poor <40%',
                                PdfColors.red,
                                textWhite,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 25),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          'Program Duration: ',
                          style: pw.TextStyle(fontSize: 10, color: textGray),
                        ),
                        pw.Text(
                          '${_userStats['programStartDate'] != null ? (_userStats['programStartDate'] as DateTime).toString().split(' ')[0] : 'N/A'} - ${DateTime.now().toString().split(' ')[0]}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: textWhite,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: pw.EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColor(
                            accentPurple.red,
                            accentPurple.green,
                            accentPurple.blue,
                            0.3,
                          ),
                          width: 1,
                        ),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Completion ID',
                            style: pw.TextStyle(fontSize: 8, color: textGray),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            _completeId,
                            style: pw.TextStyle(
                              fontSize: 7,
                              color: textWhite,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Spacer(),
                    pw.Column(
                      children: [
                        pw.Container(
                          width: 150,
                          height: 2,
                          decoration: pw.BoxDecoration(
                            gradient: pw.LinearGradient(
                              colors: [lightPurple, accentPurple],
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 15),
                        pw.Text(
                          'SNOOZIO',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: lightPurple,
                            letterSpacing: 2,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Your Sleep Journey Companion',
                          style: pw.TextStyle(fontSize: 9, color: textGray),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'snoozio.helpdesk@gmail.com',
                          style: pw.TextStyle(fontSize: 8, color: textGray),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPDFStatBox(
    String label,
    String value,
    PdfColor bgColor,
    PdfColor textColor,
  ) {
    return pw.Container(
      width: 130,
      padding: pw.EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColor(
                textColor.red,
                textColor.green,
                textColor.blue,
                0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFLegend(String label, PdfColor color, PdfColor textColor) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 10,
          height: 10,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: pw.TextStyle(fontSize: 7, color: textColor)),
      ],
    );
  }

  PdfColor _getPDFPerformanceColor(int score) {
    if (score >= 80) return PdfColors.green;
    if (score >= 60) return PdfColors.yellow;
    if (score >= 40) return PdfColors.orange;
    return PdfColors.red;
  }

  Future<File> _savePDF(Uint8List bytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _shareCertificate() async {
    try {
      final pdf = await _generatePDF();
      final file = await _savePDF(pdf, 'snoozio_completion_certificate.pdf');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'My Snoozio Program Completion Certificate',
        ),
      );
      await _submitFeedbackAndContinue();
      await _showExitDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing certificate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePDFOnly() async {
    try {
      final pdf = await _generatePDF();
      final file = await _savePDF(pdf, 'snoozio_completion_certificate.pdf');

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Save your Snoozio Completion Certificate',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate ready! Choose where to save it.'),
            backgroundColor: Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving certificate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitFeedbackAndContinue() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user.uid,
        'displayName': userData['displayName'] ?? 'Anonymous',
        'email': user.email,
        'isGuest': userData['isGuest'] ?? false,
        'rating': _currentRating,
        'carePlan': _userStats['carePlan'],
        'programStartDate': _userStats['programStartDate'],
        'programEndDate': Timestamp.now(),
        'overallScore': _userStats['overallScore'],
        'completerId': _completeId,
        'stats': {
          'totalCompleted': _userStats['totalCompleted'],
          'totalSkipped': _userStats['totalSkipped'],
          'totalMissed': _userStats['totalMissed'],
          'totalPending': _userStats['totalPending'],
        },
        'submittedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'assessment': 4,
            'currentDay': 0,
            'programStartDate': null,
            'programEndDate': null,
            'currentDayDate': null,
            'lastCompletionDate': FieldValue.serverTimestamp(),
          });

      final activityStatusQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activity_status')
          .get();
      for (final doc in activityStatusQuery.docs) {
        await doc.reference.delete();
      }

      final sleepDiaryQuery = await FirebaseFirestore.instance
          .collection('sleepDiary')
          .where('userId', isEqualTo: user.uid)
          .get();
      for (final doc in sleepDiaryQuery.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Thank you for your feedback!'),
            backgroundColor: Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showExitDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A0D2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'What\'s Next?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Would you like to take the assessment again to start a new journey, or log out?',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('logout'),
              child: const Text(
                'Log Out',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('assessment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Take Assessment Again',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == 'assessment') {
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/assessment', (route) => false);
      }
    } else if (result == 'logout') {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/splashauth', (route) => false);
      }
    }
  }

  Future<void> _showConfirmationDialog(Future<void> Function() action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A0D2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Confirm Action',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to proceed with this action?',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await action();
    }
  }

  Future<void> _showSaveOrShareDialog() async {
    if (_currentRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A0D2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Choose Action',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'How would you like to proceed with your certificate?',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: const Text(
                'Save to Device',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Share to Apps',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == 'save') {
      await _savePDFOnly();
      await _submitFeedbackAndContinue();
      await _showExitDialog();
    } else if (result == 'share') {
      await _shareCertificate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0A1A),
        body: _isLoadingStats
            ? const _LoadingState()
            : Stack(
                fit: StackFit.expand,
                children: [
                  _buildBackground(),
                  ConfettiWidget(
                    confettiController: _blastConfettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [
                      Colors.green,
                      Colors.blue,
                      Colors.pink,
                      Colors.orange,
                      Colors.purple,
                    ],
                  ),
                  SafeArea(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 32),
                          _buildStatsOverview(),
                          const SizedBox(height: 32),
                          _buildPerformanceCalendar(),
                          const SizedBox(height: 32),
                          _buildRatingSection(),
                          const SizedBox(height: 32),
                          _buildCompleteIdSection(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2E1A47).withValues(alpha: 0.8),
            const Color(0xFF1A0D2E).withValues(alpha: 0.9),
            const Color(0xFF0D0A1A).withValues(alpha: 0.95),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1).animate(
                CurvedAnimation(
                  parent: _confettiController,
                  curve: Curves.elasticOut,
                ),
              ),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF27AE60), Color(0xFF229954)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF27AE60).withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🎉', style: TextStyle(fontSize: 60)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Program Complete!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ve completed your 30-day sleep journey!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Journey',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  label: 'Completed',
                  value: (_userStats['totalCompleted'] ?? 0).toString(),
                  color: const Color(0xFF27AE60),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: HugeIcons.strokeRoundedSkippingRope,
                  label: 'Skipped',
                  value: (_userStats['totalSkipped'] ?? 0).toString(),
                  color: const Color(0xFF6C5CE7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: HugeIcons.strokeRoundedAlertCircle,
                  label: 'Missed',
                  value: (_userStats['totalMissed'] ?? 0).toString(),
                  color: const Color(0xFFE74C3C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: HugeIcons.strokeRoundedMedal01,
                  label: 'Overall Score',
                  value: '${_userStats['overallScore'] ?? 0}%',
                  color: _getPerformanceColor(_userStats['overallScore'] ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required List<List<dynamic>> icon,
    required String label,
    required String value,
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
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: HugeIcon(icon: icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '30-Day Performance Timeline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _dayPerformances.length,
                  itemBuilder: (context, index) {
                    final day = _dayPerformances[index];
                    final color = _getPerformanceColor(day.performanceScore);
                    return Tooltip(
                      message:
                          'Day ${day.day}: ${day.performanceScore}% (${day.completed} done)',
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: color.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendItem('Excellent', const Color(0xFF27AE60)),
                    _buildLegendItem('Good', const Color(0xFFFFD700)),
                    _buildLegendItem('Fair', const Color(0xFFFF9800)),
                    _buildLegendItem('Poor', const Color(0xFFE74C3C)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6C5CE7).withValues(alpha: 0.2),
              const Color(0xFF5A189A).withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF9D4EDD).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D4EDD).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedStar,
                    color: Color(0xFFE0AAFF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Let\'s Wrap Up!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Rate your experience and download your certificate!',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => GestureDetector(
                    onTap: () => setState(() => _currentRating = index + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: AnimatedScale(
                        scale: _currentRating > index ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedStar,
                          size: 40,
                          color: _currentRating > index
                              ? const Color(0xFFFFD700)
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedInformationCircle,
                    color: Color(0xFFE0AAFF),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your feedback helps us improve Snoozio for everyone',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmittingRating
                  ? null
                  : () => _showConfirmationDialog(_showSaveOrShareDialog),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isSubmittingRating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Submit and Save Your Certificate',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteIdSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    color: Color(0xFF27AE60),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Completion ID',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your unique program completion identifier',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _completeId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _completeId));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Completion ID copied to clipboard'),
                            backgroundColor: Color(0xFF27AE60),
                          ),
                        );
                      }
                    },
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCopy01,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2E1A47).withValues(alpha: 0.8),
            const Color(0xFF1A0D2E).withValues(alpha: 0.9),
            const Color(0xFF0D0A1A).withValues(alpha: 0.95),
          ],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

class DayPerformance {
  final int day;
  final int completed;
  final int skipped;
  final int missed;
  final int pending;
  final int performanceScore;
  final DateTime date;

  DayPerformance({
    required this.day,
    required this.completed,
    required this.skipped,
    required this.missed,
    required this.pending,
    required this.performanceScore,
    required this.date,
  });
}
