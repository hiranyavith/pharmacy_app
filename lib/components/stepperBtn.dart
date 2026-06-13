// ─────────────────────────────────────────────────────────────
// Stepper button (left/right sides of qty input)
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:pharmacy_app/utils/app_theme.dart';

class StepperBtn extends StatelessWidget {
  final IconData     icon;
  final bool         enabled, isLeft;
  final VoidCallback onTap;
  const StepperBtn({
    required this.icon,
    required this.enabled,
    required this.isLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 36,
      height: double.infinity,
      decoration: BoxDecoration(
        color: enabled
            ? AppTheme.primary.withOpacity(0.06)
            : Colors.grey[50],
        borderRadius: BorderRadius.only(
          topLeft:     Radius.circular(isLeft ? 7 : 0),
          bottomLeft:  Radius.circular(isLeft ? 7 : 0),
          topRight:    Radius.circular(isLeft ? 0 : 7),
          bottomRight: Radius.circular(isLeft ? 0 : 7),
        ),
        border: Border(
          right: isLeft
              ? BorderSide(color: Colors.grey[300]!)
              : BorderSide.none,
          left: isLeft
              ? BorderSide.none
              : BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Icon(
        icon,
        size: 16,
        color: enabled ? AppTheme.primary : Colors.grey[300],
      ),
    ),
  );
}