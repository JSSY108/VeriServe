import 'package:flutter/material.dart';
import '../theme/veriserve_colors.dart';

/// Veracity Confidence gauge — linear bar with percentage text.
class ConfidenceGauge extends StatelessWidget {
  final double percentage;
  final String? label;
  final double width;

  const ConfidenceGauge({
    super.key,
    required this.percentage,
    this.label,
    this.width = 128,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (label != null)
          Text(
            label!.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: VeriServeColors.onSurfaceVariant,
                ),
          ),
        if (label != null) const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: VeriServeColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: VeriServeColors.outlineVariant),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (percentage / 100).clamp(0, 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: VeriServeColors.deepNavy,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: VeriServeColors.deepNavy,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
