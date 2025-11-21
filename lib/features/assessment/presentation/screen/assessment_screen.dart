import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:snoozio/features/assessment/logic/model/sleep_assessment_model.dart';
import 'package:snoozio/features/assessment/logic/controller/assessment_controller.dart';
import 'package:zhi_starry_sky/starry_sky.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  AssessmentScreenState createState() => AssessmentScreenState();
}

class AssessmentScreenState extends State<AssessmentScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final AssessmentController _assessmentService = AssessmentController();
  List<AssessmentQuestion> _questions = [];
  final Map<int, int> _answers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final fetchedQuestions = await _assessmentService.fetchSleepAssessment();
      if (mounted) {
        setState(() => _questions = fetchedQuestions);
      }
    } catch (e) {
      debugPrint('Error loading questions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateTotalScore() {
    return _answers.values.fold(0, (summing, value) => summing + value);
  }

  int _getCategoryFromScore(int score) {
    if (score <= 5) return 0;
    if (score <= 9) return 1;
    if (score <= 14) return 2;
    if (score <= 21) return 3;
    return 4;
  }

  void _nextPage() {
    if (_currentPage < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _submitAssessment();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitAssessment() async {
    final totalScore = _calculateTotalScore();
    final categoryScore = _getCategoryFromScore(totalScore);

    debugPrint("🧮 total score: $totalScore");
    debugPrint("📊 category score: $categoryScore");

    try {
      final user = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint("No user is currently signed in.");
        return;
      }

      final userDoc = user.collection('users').doc(currentUser.uid);
      await userDoc.update({'assessment': categoryScore});

      debugPrint(
        "Updated 'assessment' to $categoryScore for ${currentUser.uid}",
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/onboarding',
        arguments: {'totalScore': totalScore, 'categoryScore': categoryScore},
      );
    } on FirebaseException catch (e) {
      debugPrint("⚠️ Firestore error [${e.code}]: ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save assessment. (${e.code})"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      debugPrint(" Unexpected error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("An unexpected error occurred."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              -1,
              0,
              0,
              0,
              255,
              0,
              -1,
              0,
              0,
              255,
              0,
              0,
              -1,
              0,
              255,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: const StarrySkyView(),
          ),

          Container(
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
          ),

          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : _questions.isEmpty
                ? const Center(
                    child: Text(
                      "No questions available.",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                : Column(
                    children: [
                      _buildHeader(),
                      _buildProgressBar(),
                      const SizedBox(height: 20),

                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                          },
                          itemCount: _questions.length,
                          itemBuilder: (context, index) {
                            return _buildQuestionPage(_questions[index], index);
                          },
                        ),
                      ),

                      _buildNavigationButtons(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _currentPage > 0 ? _previousPage : null,
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: Colors.white,
            ),
          ),
          Column(
            children: [
              Text(
                "Sleep Assessment",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Question ${_currentPage + 1} of ${_questions.length}",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: (_currentPage + 1) / _questions.length,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5FD6)),
          minHeight: 8,
        ),
      ),
    );
  }

  Widget _buildQuestionPage(AssessmentQuestion question, int questionIndex) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              question.question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 32),

          ...List.generate(question.options.length, (optionIndex) {
            final isSelected = _answers[questionIndex] == optionIndex;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildOptionCard(
                question.options[optionIndex],
                optionIndex,
                isSelected,
                () {
                  setState(() {
                    _answers[questionIndex] = optionIndex;
                  });
                },
              ),
            );
          }),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    String text,
    int value,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF8B5FD6), Color(0xFF6A3FB5)],
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8B5FD6)
                : Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF8B5FD6).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                color: isSelected ? Colors.white : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF8B5FD6),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              "$value",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final canProceed = _answers.containsKey(_currentPage);
    final isLastQuestion = _currentPage == _questions.length - 1;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: const BorderSide(color: Colors.white, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Back",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: canProceed
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5FD6), Color(0xFF6A3FB5)],
                      )
                    : null,
                color: canProceed ? null : Colors.white.withValues(alpha: 0.2),
                boxShadow: canProceed
                    ? [
                        BoxShadow(
                          color: const Color(0xFF8B5FD6).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: ElevatedButton(
                onPressed: canProceed ? _nextPage : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  disabledBackgroundColor: Colors.transparent,
                ),
                child: Text(
                  isLastQuestion ? "Complete Assessment" : "Next",
                  style: TextStyle(
                    color: canProceed
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
