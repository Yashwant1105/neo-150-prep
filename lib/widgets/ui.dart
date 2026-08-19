import 'package:flutter/material.dart';
import 'app_theme.dart';

class GlowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const GlowCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      padding: padding,
      child: child,
    );
    return onTap == null ? card : InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: card,
    );
  }
}

class DifficultyPill extends StatelessWidget {
  final String difficulty;
  const DifficultyPill({super.key, required this.difficulty});
  @override
  Widget build(BuildContext context) {
    final text = difficulty == 'Easy' ? 'EASY' : difficulty == 'Medium' ? 'MED' : 'HARD';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: difficulty == 'Easy' ? const Color(0x1A6EEB83) : difficulty == 'Medium' ? const Color(0x1AFFC857) : const Color(0x1AFF5E6B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .8)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  const SectionTitle({super.key, required this.title, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const Spacer(),
      if (trailing != null) TextButton(onPressed: onTap, child: Text(trailing!)),
    ],
  );
}
