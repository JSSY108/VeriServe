import 'package:flutter/material.dart';
import '../models/claim.dart';
import '../theme/veriserve_colors.dart';

/// Status badge matching the Stitch design: tinted background + colored text + border.
class StatusBadge extends StatelessWidget {
  final ClaimStatus status;
  final bool humanVerified;

  const StatusBadge({super.key, required this.status, this.humanVerified = false});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status, humanVerified);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (config.icon != null) ...[
            Icon(config.icon, size: 12, color: config.textColor),
            const SizedBox(width: 4),
          ],
          Text(
            config.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getConfig(ClaimStatus status, bool humanVerified) {
    switch (status) {
      case ClaimStatus.resolved:
        return _BadgeConfig(
          label: humanVerified ? 'Human-Verified' : 'AI-Verified',
          background: Color(0xFFF0FDF4),
          border: Color(0xFFBBF7D0),
          textColor: VeriServeColors.successGreen,
          icon: Icons.check_circle_outline,
        );
      case ClaimStatus.submitted:
      case ClaimStatus.ingesting:
      case ClaimStatus.investigating:
      case ClaimStatus.auditing:
        return const _BadgeConfig(
          label: 'Pending Review',
          background: VeriServeColors.surfaceContainerHighest,
          border: VeriServeColors.outlineVariant,
          textColor: VeriServeColors.onSurfaceVariant,
          icon: Icons.pending,
        );
      case ClaimStatus.denied:
        return const _BadgeConfig(
          label: 'Fraud Alert',
          background: Color(0xFFFEF2F2),
          border: Color(0xFFFECACA),
          textColor: VeriServeColors.error,
          icon: Icons.warning_amber,
        );
      case ClaimStatus.escalated:
        return const _BadgeConfig(
          label: 'Escalated',
          background: Color(0xFFFFFBEB),
          border: Color(0xFFFDE68A),
          textColor: VeriServeColors.alertOrange,
          icon: Icons.escalator_warning,
        );
    }
  }
}

class _BadgeConfig {
  final String label;
  final Color background;
  final Color border;
  final Color textColor;
  final IconData? icon;

  const _BadgeConfig({
    required this.label,
    required this.background,
    required this.border,
    required this.textColor,
    this.icon,
  });
}
