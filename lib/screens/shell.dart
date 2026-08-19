import 'package:flutter/material.dart';

import '../widgets/mp_icon.dart';
import 'home_screen.dart';
import 'problems_screen.dart';
import 'progress_screen.dart';
import 'achievements_screen.dart';
import 'profile_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  final pages = const [
    HomeScreen(),
    ProblemsScreen(),
    ProgressScreen(),
    AchievementsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          setState(() => index = i);
        },
        backgroundColor: const Color(0xF20D1210),
        indicatorColor: const Color(0x1FB7FF4A),
        destinations: const [
          NavigationDestination(
            icon: MpIcon(
              'core/home',
              size: 25,
            ),
            selectedIcon: MpIcon(
              'core/home',
              size: 25,
              color: Color(0xFFB7FF4A),
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: MpIcon(
              'core/code',
              size: 25,
            ),
            selectedIcon: MpIcon(
              'core/code',
              size: 25,
              color: Color(0xFFB7FF4A),
            ),
            label: 'Problems',
          ),
          NavigationDestination(
            icon: MpIcon(
              'core/insights',
              size: 25,
            ),
            selectedIcon: MpIcon(
              'core/insights',
              size: 25,
              color: Color(0xFFB7FF4A),
            ),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: MpIcon(
              'core/achievements',
              size: 25,
            ),
            selectedIcon: MpIcon(
              'core/achievements',
              size: 25,
              color: Color(0xFFB7FF4A),
            ),
            label: 'Awards',
          ),
          NavigationDestination(
            icon: MpIcon(
              'core/profile',
              size: 25,
            ),
            selectedIcon: MpIcon(
              'core/profile',
              size: 25,
              color: Color(0xFFB7FF4A),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
