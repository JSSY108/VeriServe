import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/veriserve_colors.dart';
import '../../models/claim.dart';

/// Phase 3: Result Screen — Final verdict (Approved/Denied/Escalated).
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final claim = state.activeClaim;
    final isApproved = claim?.status == ClaimStatus.resolved;
    final isDenied = claim?.status == ClaimStatus.denied;

    return Container(
      color: VeriServeColors.background,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
          decoration: const BoxDecoration(
              color: VeriServeColors.surface,
              border: Border(
                  bottom: BorderSide(
                      color: VeriServeColors.surfaceContainerHighest))),
          child: Column(children: [
            Text('Claim Resolution',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('#${claim?.orderId ?? 'SHP-112'}',
                style: const TextStyle(
                    fontSize: 14,
                    color: VeriServeColors.onSurfaceVariant,
                    fontFamily: 'monospace')),
          ]),
        ),

        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 24),

            // Status icon
            Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isApproved
                        ? const Color(0xFFF0FDF4)
                        : isDenied
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFFFFBEB)),
                child: Icon(
                  isApproved
                      ? Icons.check_circle
                      : isDenied
                          ? Icons.cancel
                          : Icons.warning,
                  size: 48,
                  color: isApproved
                      ? VeriServeColors.successGreen
                      : isDenied
                          ? VeriServeColors.error
                          : VeriServeColors.alertOrange,
                )),
            const SizedBox(height: 16),

            Text(
                isApproved
                    ? 'Refund Approved'
                    : isDenied
                        ? 'Claim Denied'
                        : 'Under Review',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: isApproved
                        ? VeriServeColors.successGreen
                        : isDenied
                            ? VeriServeColors.error
                            : VeriServeColors.alertOrange)),
            const SizedBox(height: 8),

            Text(
                isApproved
                    ? 'Your claim has been verified and approved for automatic refund.'
                    : isDenied
                        ? 'Our investigation found inconsistencies with your claim.'
                        : 'Your claim has been escalated for manual review.',
                style: const TextStyle(
                    fontSize: 14,
                    color: VeriServeColors.onSurfaceVariant,
                    height: 1.5),
                textAlign: TextAlign.center),

            const SizedBox(height: 32),

            // Details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: VeriServeColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VeriServeColors.outlineVariant)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detail('Confidence Score',
                        '${claim?.confidence?.toStringAsFixed(1) ?? '—'}%'),
                    const SizedBox(height: 12),
                    _detail('Merchant', claim?.merchant ?? '—'),
                    const SizedBox(height: 12),
                    _detail('Category', claim?.category ?? '—'),
                    const SizedBox(height: 12),
                    _detail('Amount',
                        'RM ${claim?.claimAmount?.toStringAsFixed(2) ?? '—'}'),
                    if (isApproved) ...[
                      const SizedBox(height: 12),
                      _detail('Disbursement', 'Instant via Veracity-Net'),
                    ],
                  ]),
            ),

            const SizedBox(height: 16),

            // Verification trace link
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: VeriServeColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.receipt_long,
                    size: 16, color: VeriServeColors.onSurfaceVariant),
                SizedBox(width: 8),
                Text('View Full Verification Trace',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: VeriServeColors.onSurfaceVariant,
                        decoration: TextDecoration.underline)),
              ]),
            ),

            const SizedBox(height: 32),

            // Submit new claim
            SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => state.resetCustomerFlow(),
                  child: const Text('Submit Another Claim'),
                )),
          ]),
        )),
      ]),
    );
  }

  Widget _detail(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 14, color: VeriServeColors.onSurfaceVariant)),
      Text(value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    ]);
  }
}
