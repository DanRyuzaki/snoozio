import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:snoozio/features/assessment/logic/model/sleep_assessment_model.dart';

class AssessmentController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<AssessmentQuestion>> fetchSleepAssessment() async {
    try {
      final snapshot = await _firestore
          .collection('assessments')
          .doc('sleep_assessment')
          .get();

      if (!snapshot.exists) {
        throw Exception("sleep_assessment not found");
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final List<dynamic> questions = data['questions'] ?? [];

      return questions.map((q) {
        final String questionText = q['question'] ?? '';
        final Map<String, dynamic> optionsMap = Map<String, dynamic>.from(
          q['options'] ?? {},
        );
        final List<String> options = optionsMap.values
            .map((e) => e.toString())
            .toList();

        return AssessmentQuestion(question: questionText, options: options);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching assessment: $e');
      return [];
    }
  }

  Future<String?> getLatestVersionForCategory(int categoryScore) async {
    try {
      String carePlanName;
      switch (categoryScore) {
        case 0:
          carePlanName = 'normal';
          break;
        case 1:
          carePlanName = 'mild';
          break;
        case 2:
          carePlanName = 'moderate';
          break;
        case 3:
          carePlanName = 'severe';
          break;
        case 4:
          carePlanName = 'very_severe';
          break;
        default:
          carePlanName = 'normal';
      }

      final snapshot = await _firestore
          .collection('care_plans')
          .doc(carePlanName)
          .collection('versions')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('No versions found for $carePlanName');
        return null;
      }

      String? latestVersion;
      int highestVersionNumber = 0;

      for (var doc in snapshot.docs) {
        final versionName = doc.id;

        final versionNumberMatch = RegExp(r'v?(\d+)').firstMatch(versionName);
        if (versionNumberMatch != null) {
          final versionNumber =
              int.tryParse(versionNumberMatch.group(1) ?? '0') ?? 0;

          if (versionNumber > highestVersionNumber) {
            highestVersionNumber = versionNumber;
            latestVersion = versionName;
          }
        }
      }

      debugPrint('Latest version for $carePlanName: $latestVersion');
      return latestVersion;
    } catch (e) {
      debugPrint('Error fetching latest version: $e');
      return null;
    }
  }
}
