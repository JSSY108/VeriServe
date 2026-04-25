import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/veriserve_colors.dart';

/// Floating action button to toggle between Admin and User modes.
class ModeToggleFab extends StatelessWidget {
  const ModeToggleFab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isAdmin = state.isAdminMode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => state.toggleMode(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isAdmin
                ? VeriServeColors.deepNavy.withValues(alpha: 0.8)
                : VeriServeColors.primaryContainer,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAdmin ? Icons.person : Icons.admin_panel_settings,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isAdmin ? 'Switch to User Mode' : 'Switch to God Mode',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
