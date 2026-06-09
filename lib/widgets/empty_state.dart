import 'package:flutter/material.dart';
import '../theme/lrc_theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   body;
  final LrcTheme theme;
  final String?  buttonLabel;
  final VoidCallback? onButton;

  const EmptyState({
    super.key,
    required this.icon,  required this.color,
    required this.title, required this.body,
    required this.theme,
    this.buttonLabel,    this.onButton,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: theme.textPrimary)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center,
                 style: TextStyle(fontSize: 13, color: theme.textSecondary, height: 1.5)),
                 if (buttonLabel != null && onButton != null) ...[
                   const SizedBox(height: 24),
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: color,
                       foregroundColor: Colors.white,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                     ),
                     onPressed: onButton,
                     child: Text(buttonLabel!, style: const TextStyle(fontWeight: FontWeight.w600)),
                   ),
                 ],
        ],
      ),
    ),
  );
}
