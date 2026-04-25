import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/veriserve_colors.dart';
import '../../models/merchant_policy.dart';

/// Merchant Policy Editor — configure auto-refund thresholds and certainty cutoffs.
class MerchantPolicyScreen extends StatefulWidget {
  final String merchantId;
  const MerchantPolicyScreen({super.key, required this.merchantId});

  @override
  State<MerchantPolicyScreen> createState() => _MerchantPolicyScreenState();
}

class _MerchantPolicyScreenState extends State<MerchantPolicyScreen> {
  late TextEditingController _thresholdCtrl;
  late TextEditingController _certaintyCtrl;
  late TextEditingController _maxAmountCtrl;

  @override
  void initState() {
    super.initState();
    final policy = context.read<AppState>().getPolicy(widget.merchantId);
    _thresholdCtrl = TextEditingController(
        text: policy?.autoRefundThreshold.toStringAsFixed(0) ?? '50');
    _certaintyCtrl = TextEditingController(
        text: policy?.certaintyCutoff.toStringAsFixed(0) ?? '95');
    _maxAmountCtrl = TextEditingController(
        text: policy?.maxAutoAmount.toStringAsFixed(0) ?? '200');
  }

  @override
  void dispose() {
    _thresholdCtrl.dispose();
    _certaintyCtrl.dispose();
    _maxAmountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final policy = state.getPolicy(widget.merchantId);
    if (policy == null)
      return const Scaffold(body: Center(child: Text('Policy not found')));

    return Scaffold(
      backgroundColor: VeriServeColors.background,
      appBar: AppBar(title: Text('Policy Editor — ${policy.merchantName}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Automated Resolution Parameters',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            const Text(
                'Configure the thresholds that drive the Auditor Agent\'s autonomous approval decisions.',
                style: TextStyle(color: VeriServeColors.onSurfaceVariant)),
            const SizedBox(height: 32),

            _field('Auto-Refund Threshold (RM)', _thresholdCtrl,
                'Maximum claim value for automated approval'),
            const SizedBox(height: 20),
            _field('Certainty Cutoff (%)', _certaintyCtrl,
                'Minimum confidence score required for auto-approval'),
            const SizedBox(height: 20),
            _field('Max Auto Amount (RM)', _maxAmountCtrl,
                'Hard cap for automated payouts'),
            const SizedBox(height: 32),

            // Categories
            const Text('CATEGORY MATRIX',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: VeriServeColors.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: policy.categories
                    .map((cat) => Chip(
                        label: Text(cat),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {}))
                    .toList()),

            const SizedBox(height: 40),
            Row(children: [
              OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              const SizedBox(width: 12),
              ElevatedButton(
                  onPressed: () {
                    state.updatePolicy(policy.copyWith(
                      autoRefundThreshold:
                          double.tryParse(_thresholdCtrl.text) ??
                              policy.autoRefundThreshold,
                      certaintyCutoff: double.tryParse(_certaintyCtrl.text) ??
                          policy.certaintyCutoff,
                      maxAutoAmount: double.tryParse(_maxAmountCtrl.text) ??
                          policy.maxAutoAmount,
                    ));
                    Navigator.pop(context);
                  },
                  child: const Text('Save & Publish Policy')),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: VeriServeColors.onSurfaceVariant)),
      const SizedBox(height: 8),
      TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hint),
          keyboardType: TextInputType.number),
    ]);
  }
}
