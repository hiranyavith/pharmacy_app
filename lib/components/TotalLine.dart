import 'package:flutter/material.dart';
import 'package:pharmacy_app/utils/app_theme.dart';

class TotalLine extends StatelessWidget {
  final String label, value;
  final bool large, bold;
  final Color color;
  const TotalLine(this.label, this.value,
      {this.large = false, this.bold = false, this.color = AppTheme.textMain});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: AppTheme.textSub,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 16 : 14)),
          ],
        ),
      );
}