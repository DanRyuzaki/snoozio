import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snoozio/core/background/background_service_manager.dart' as bg;
import 'package:snoozio/features/main/presentation/pages/todo/todo_screen.dart';
import 'package:snoozio/features/main/presentation/pages/dashboard/dashboard_screen.dart';
import 'package:snoozio/features/main/presentation/pages/alarm/alarm_screen.dart';
import 'package:snoozio/features/main/logic/main_controller.dart';
import 'package:snoozio/features/main/presentation/pages/drawer/app_drawer.dart';
import 'package:snoozio/features/main/logic/music/music_player_controller.dart';
import 'package:snoozio/features/main/presentation/pages/music/music_player_dialog.dart';
import 'package:zhi_starry_sky/starry_sky.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int navigationIndex = 1;
  final PageController _pageController = PageController(initialPage: 1);
  final MainController _mainController = MainController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _saveUserIdForBackground();
    _checkProgramCompletion();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  Future<void> _checkProgramCompletion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final currentDay = userDoc['currentDay'] ?? 0;

    if (currentDay > 30 && mounted) {
      Navigator.of(context).pushReplacementNamed('/completion');
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _saveUserIdForBackground() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', user.uid);
      debugPrint('✅ User ID saved in MainScreen: ${user.uid}');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final currentDay = data['currentDay'] ?? 0;
        final currentDayDate = (data['currentDayDate'] as Timestamp?)?.toDate();

        if (currentDay > 0 && currentDayDate != null) {
          final now = DateTime.now();
          final todayMidnight = DateTime(now.year, now.month, now.day);
          final dayDateMidnight = DateTime(
            currentDayDate.year,
            currentDayDate.month,
            currentDayDate.day,
          );

          if (!todayMidnight.isBefore(dayDateMidnight)) {
            await bg.BackgroundServiceManager.scheduleAllRemindersForToday(
              'auto',
              0,
            );
            debugPrint('✅ Reminders scheduled from MainScreen');
          } else {
            debugPrint(
              '⏳ Day not ready - reminders NOT scheduled from MainScreen',
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: const AppDrawer(),
      bottomNavigationBar: CurvedNavigationBar(
        height: 65,
        color: const Color(0xFF1E0F33),
        backgroundColor: Colors.transparent,
        items: <Widget>[
          HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar01,
            size: 30,
            color: navigationIndex == 0 ? Colors.white : Colors.grey,
          ),
          HugeIcon(
            icon: HugeIcons.strokeRoundedDashboardSquare01,
            size: 30,
            color: navigationIndex == 1 ? Colors.white : Colors.grey,
          ),
          HugeIcon(
            icon: HugeIcons.strokeRoundedClock04,
            size: 30,
            color: navigationIndex == 2 ? Colors.white : Colors.grey,
          ),
        ],
        index: navigationIndex,
        onTap: (index) {
          setState(() => navigationIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColorFiltered(
            colorFilter: ColorFilter.matrix([
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
            child: StarrySkyView(),
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
            top: true,
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StreamBuilder<DocumentSnapshot>(
                        stream: _mainController.getUserDataStream(),
                        builder: (context, snapshot) {
                          String avatar = '😊';
                          String displayName = 'User';

                          if (snapshot.hasData && snapshot.data!.exists) {
                            avatar = _mainController.getAvatar(snapshot.data!);
                            displayName = _mainController.getDisplayName(
                              snapshot.data!,
                            );
                          }

                          return GestureDetector(
                            onTap: () {
                              _scaffoldKey.currentState?.openDrawer();
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                  child: Center(
                                    child: Text(
                                      avatar,
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      _getGreeting(),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      Consumer<MusicPlayerController>(
                        builder: (context, musicController, child) {
                          if (musicController.isPlaying) {
                            if (!_rotationController.isAnimating) {
                              _rotationController.repeat();
                            }
                          } else {
                            if (_rotationController.isAnimating) {
                              _rotationController.stop();
                            }
                          }

                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: musicController.isPlaying
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(
                                          0xFF9D4EDD,
                                        ).withValues(alpha: 0.4),
                                        const Color(
                                          0xFF6C5CE7,
                                        ).withValues(alpha: 0.4),
                                      ],
                                    )
                                  : null,
                              color: musicController.isPlaying
                                  ? null
                                  : Colors.white.withValues(alpha: 0.15),
                              border: musicController.isPlaying
                                  ? Border.all(
                                      color: const Color(0xFF9D4EDD),
                                      width: 2,
                                    )
                                  : null,
                              boxShadow: musicController.isPlaying
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF9D4EDD,
                                        ).withValues(alpha: 0.5),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: const Color(
                                          0xFF6C5CE7,
                                        ).withValues(alpha: 0.3),
                                        blurRadius: 24,
                                        spreadRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: AnimatedBuilder(
                              animation: _rotationController,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: musicController.isPlaying
                                      ? _rotationController.value * 2 * 3.14159
                                      : 0,
                                  child: IconButton(
                                    icon: HugeIcon(
                                      icon: musicController.isPlaying
                                          ? HugeIcons.strokeRoundedMusicNote04
                                          : HugeIcons.strokeRoundedMusicNote03,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            const MusicPlayerDialog(),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => navigationIndex = index);
                    },
                    children: [
                      const ToDoSection(),
                      DashboardSection(
                        onNavigateToTodo: () {
                          setState(() => navigationIndex = 0);
                          _pageController.animateToPage(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                      const AlarmScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }
}
