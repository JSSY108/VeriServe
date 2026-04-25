import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/veriserve_colors.dart';
import '../../models/claim.dart';

/// Phase 2: Processing Screen — "Vision Analysis in Progress" animation.
class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final claim = state.activeClaim;
    final status = claim?.status ?? ClaimStatus.ingesting;

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
            Text('Analyzing Claim',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('#${claim?.orderId ?? 'SHP-112'}',
                style: const TextStyle(
                    fontSize: 14,
                    color: VeriServeColors.onSurfaceVariant,
                    fontFamily: 'monospace')),
          ]),
        ),

        // Processing content
        Expanded(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Animated spinner
            const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: VeriServeColors.deepNavy,
                    backgroundColor: VeriServeColors.surfaceVariant)),
            const SizedBox(height: 32),

            Text('Vision Analysis in Progress',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Our AI agents are verifying your claim',
                style: TextStyle(color: VeriServeColors.onSurfaceVariant)),
            const SizedBox(height: 40),

            // Agent pipeline steps
            _agentStep(
                1,
                'Ingestor Agent',
                'Extracting entities from claim...',
                status.index >= ClaimStatus.ingesting.index,
                status.index > ClaimStatus.ingesting.index),
            const SizedBox(height: 16),
            _agentStep(
                2,
                'Investigator Agent',
                'Comparing visual evidence...',
                status.index >= ClaimStatus.investigating.index,
                status.index > ClaimStatus.investigating.index),
            const SizedBox(height: 16),
            _agentStep(
                3,
                'Auditor Agent',
                'Checking merchant policies...',
                status.index >= ClaimStatus.auditing.index,
                status.index > ClaimStatus.auditing.index),
          ]),
        )),
      ]),
    );
  }

  Widget _agentStep(
      int num, String title, String subtitle, bool isActive, bool isDone) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? VeriServeColors.surface
            : VeriServeColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDone
                ? VeriServeColors.successGreen
                : isActive
                    ? VeriServeColors.deepNavy
                    : VeriServeColors.outlineVariant),
      ),
      child: Row(children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? VeriServeColors.successGreen
                    : isActive
                        ? VeriServeColors.deepNavy
                        : VeriServeColors.surfaceContainer),
            child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : isActive
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('$num',
                            style: const TextStyle(
                                color: VeriServeColors.onSurfaceVariant,
                                fontWeight: FontWeight.w600)))),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? VeriServeColors.onSurface
                      : VeriServeColors.onSurfaceVariant)),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: VeriServeColors.onSurfaceVariant)),
        ]),
      ]),
    );
  }
}
