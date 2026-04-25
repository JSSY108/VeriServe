import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/veriserve_colors.dart';
import 'merchant_policy_screen.dart';

/// Merchants Management screen — list of merchants with status and drill-down.
class MerchantsScreen extends StatelessWidget {
  const MerchantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final policies = state.policies.values.toList();

    return Container(
      color: VeriServeColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Registered Merchants',
                  style: Theme.of(context).textTheme.headlineLarge),
              const Spacer(),
              ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () {},
                  label: const Text('Add Merchant')),
            ]),
            const SizedBox(height: 24),

            // Merchant cards grid
            Wrap(
                spacing: 16,
                runSpacing: 16,
                children: policies
                    .map((p) => _merchantCard(context, p, state))
                    .toList()),
          ]),
        ),
      ),
    );
  }

  Widget _merchantCard(BuildContext context, dynamic policy, AppState state) {
    final claimCount =
        state.claims.where((c) => c.merchant == policy.merchantName).length;
    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VeriServeColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VeriServeColors.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: VeriServeColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8)),
              child: Center(
                  child: Text(policy.merchantName.substring(0, 2).toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(policy.merchantName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Region: ${policy.region} · ${policy.policyVersion}',
                style: const TextStyle(
                    fontSize: 12, color: VeriServeColors.onSurfaceVariant)),
          ]),
          const Spacer(),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: policy.isActive
                      ? const Color(0xFFF0FDF4)
                      : VeriServeColors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: policy.isActive
                          ? const Color(0xFFBBF7D0)
                          : VeriServeColors.error)),
              child: Text(policy.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: policy.isActive
                          ? VeriServeColors.successGreen
                          : VeriServeColors.error))),
        ]),
        const SizedBox(height: 16),
        const Divider(color: VeriServeColors.outlineVariant),
        const SizedBox(height: 12),
        Row(children: [
          _stat('Active Claims', '$claimCount'),
          const SizedBox(width: 24),
          _stat('Auto Limit',
              'RM ${policy.autoRefundThreshold.toStringAsFixed(0)}'),
          const SizedBox(width: 24),
          _stat('Certainty', '${policy.certaintyCutoff.toStringAsFixed(0)}%'),
        ]),
        const SizedBox(height: 16),
        SizedBox(
            width: double.infinity,
            child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        MerchantPolicyScreen(merchantId: policy.merchantId))),
                child: const Text('Edit Policy'))),
      ]),
    );
  }

  Widget _stat(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: VeriServeColors.onSurfaceVariant)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ]);
  }
}
