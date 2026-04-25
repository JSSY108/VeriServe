import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import 'claim_input_screen.dart';
import 'processing_screen.dart';
import 'result_screen.dart';

/// Root widget for the Customer Portal inside the phone frame.
/// Routes between 3 steps based on AppState.customerStep.
class CustomerPortal extends StatelessWidget {
  const CustomerPortal({super.key});

  @override
  Widget build(BuildContext context) {
    final step = context.watch<AppState>().customerStep;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: switch (step) {
        0 => const ClaimInputScreen(key: ValueKey('input')),
        1 => const ProcessingScreen(key: ValueKey('processing')),
        2 => const ResultScreen(key: ValueKey('result')),
        _ => const ClaimInputScreen(key: ValueKey('input')),
      },
    );
  }
}
