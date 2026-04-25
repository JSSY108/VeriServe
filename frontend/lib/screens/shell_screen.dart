import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/smartphone_frame.dart';
import '../widgets/mode_toggle_fab.dart';
import 'admin/admin_shell.dart';
import 'customer/customer_portal.dart';

/// Root Stack widget implementing the dual-persona "Window-on-Top" architecture.
/// - Admin Mode ON → full-screen SaaS
/// - Admin Mode OFF → blur admin + centered phone frame
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isAdmin = state.isAdminMode;

    return Scaffold(
      body: Stack(
        children: [
          // Layer 1: Admin SaaS (always rendered to preserve state)
          const AdminShell(),

          // Layer 2: Blur overlay (user mode)
          if (!isAdmin)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),

          // Layer 3: Phone frame with Customer Portal (user mode)
          if (!isAdmin)
            const Center(
              child: SmartphoneFrame(
                child: CustomerPortal(),
              ),
            ),

          // Layer 4: Mode toggle FAB (always visible)
          const Positioned(
            bottom: 32,
            right: 32,
            child: ModeToggleFab(),
          ),
        ],
      ),
    );
  }
}
