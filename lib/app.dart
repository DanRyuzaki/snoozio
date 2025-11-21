import 'package:flutter/material.dart';
import 'package:snoozio/features/assessment/presentation/screen/assessment_screen.dart';
import 'package:snoozio/features/completion/program_complete_screen.dart';
import 'package:snoozio/features/main/presentation/main_screen.dart';
import 'package:snoozio/features/onboarding/presentation/screen/onboarding_screen.dart';
import 'package:snoozio/features/splashauth/presentation/screen/splashauth_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snoozio',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (context) => const SplashAuthScreen(),
            );

          case '/assessment':
            return MaterialPageRoute(builder: (context) => AssessmentScreen());

          case '/onboarding':
            final args = settings.arguments as Map<String, dynamic>?;

            if (args == null) {
              return MaterialPageRoute(
                builder: (context) => AssessmentScreen(),
              );
            }

            return MaterialPageRoute(
              builder: (context) => OnboardingScreen(
                categoryScore: args['categoryScore'] as int,
                totalScore: args['totalScore'] as int,
              ),
            );

          case '/main':
            return MaterialPageRoute(builder: (context) => MainScreen());
          case '/completion':
            return MaterialPageRoute(
              builder: (context) => const ProgramCompletionScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const SplashAuthScreen(),
            );
        }
      },
    );
  }
}
