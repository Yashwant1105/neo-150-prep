import 'package:flutter/material.dart';

import '../widgets/mp_icon.dart';
import 'home_screen.dart';
import 'problems_screen.dart';
import 'interview_screen.dart';
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
    InterviewScreen(),
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
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          // NavigationBar gives every destination an equal Expanded slot.
          // We use the available width to scale the visual density so the
          // six destinations remain evenly spaced without label collisions.
          final itemWidth = constraints.maxWidth / pages.length;

          final iconSize = itemWidth < 58
              ? 21.0
              : itemWidth < 68
                  ? 22.0
                  : itemWidth < 80
                      ? 23.0
                      : 25.0;

          final labelSize = itemWidth < 58
              ? 8.5
              : itemWidth < 68
                  ? 9.5
                  : itemWidth < 80
                      ? 10.5
                      : 11.0;

          final barHeight = itemWidth < 58
              ? 68.0
              : itemWidth < 68
                  ? 70.0
                  : 74.0;

          return NavigationBar(
            height: barHeight,
            selectedIndex: index,
            onDestinationSelected: (i) {
              setState(() => index = i);
            },
            backgroundColor: const Color(0xF20D1210),
            indicatorColor: const Color(0x1FB7FF4A),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            labelPadding: EdgeInsets.zero,
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
              (states) {
                final selected = states.contains(WidgetState.selected);

                return TextStyle(
                  fontSize: labelSize,
                  height: 1.0,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0,
                );
              },
            ),
            destinations: [
              NavigationDestination(
                icon: MpIcon(
                  'core/home',
                  size: iconSize,
                ),
                selectedIcon: MpIcon(
                  'core/home',
                  size: iconSize,
                  color: const Color(0xFFB7FF4A),
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: MpIcon(
                  'core/code',
                  size: iconSize,
                ),
                selectedIcon: MpIcon(
                  'core/code',
                  size: iconSize,
                  color: const Color(0xFFB7FF4A),
                ),
                label: 'Problems',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.mic_none_rounded,
                  size: iconSize,
                ),
                selectedIcon: Icon(
                  Icons.mic_rounded,
                  size: iconSize,
                  color: const Color(0xFFB7FF4A),
                ),
                label: 'Interview',
              ),
              NavigationDestination(
                icon: MpIcon(
                  'core/insights',
                  size: iconSize,
                ),
                selectedIcon: MpIcon(
                  'core/insights',
                  size: iconSize,
                  color: const Color(0xFFB7FF4A),
                ),
                label: 'Progress',
              ),
              NavigationDestination(
                icon: MpIcon(
                  'core/achievements',
                  size: iconSize,
                ),
                selectedIcon: MpIcon(
                  'core/achievements',
                  size: iconSize,
                  color: const Color(0xFFB7FF4A),
                ),
                label: 'Awards',
              ),
              NavigationDestination(
                icon: MpIcon(
                  'core/profile',
                  size: iconSize,
                ),
                selectedIcon: MpIcon(
                  'core/profile',
                  size: iconSize,
                  color: const Color(0xFFB7FF4A),
                ),
                label: 'Profile',
              ),
            ],
          );
        },
      ),
    );
  }
}
