import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScreenWrapper extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  final bool scrollable; 

  const ScreenWrapper({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.scrollable = true, 
  });

  @override
  Widget build(BuildContext context) {
    Widget content = scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: child,
          )
        : Padding(
            padding: const EdgeInsets.all(28),
            child: child,
          );

    return Container(
      color: AppTheme.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: const Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                )),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                )),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.green.withValues(alpha:0.3)),
                ),
                child: Row(children: [
                  Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('Sistema activo', style: TextStyle(
                    color: AppTheme.green, fontSize: 12, fontWeight: FontWeight.w600,
                  )),
                ]),
              ),
            ]),
          ),
          Expanded(child: content), 
        ],
      ),
    );
  }
}