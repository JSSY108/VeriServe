import 'package:flutter/material.dart';
import '../theme/veriserve_colors.dart';

/// Reusable KPI card matching the Global Dashboard design.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String? trendText;
  final Color? trendColor;
  final double? gaugePercent;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconBackground = const Color(0xFFD6E3FF),
    this.iconColor = const Color(0xFF0D1C32),
    this.trendText,
    this.trendColor,
    this.gaugePercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VeriServeColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VeriServeColors.tertiaryFixed),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: VeriServeColors.onSurfaceVariant,
                        letterSpacing: 0.6,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.displayLarge,
          ),
          if (trendText != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 16,
                  color: trendColor ?? VeriServeColors.successGreen,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    trendText!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: trendColor ?? VeriServeColors.successGreen,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (gaugePercent != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: gaugePercent! / 100,
                backgroundColor: VeriServeColors.surfaceVariant,
                valueColor:
                    const AlwaysStoppedAnimation(VeriServeColors.successGreen),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
