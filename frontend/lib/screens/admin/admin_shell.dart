import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../widgets/sidebar_nav.dart';
import '../../theme/veriserve_colors.dart';
import 'global_dashboard_screen.dart';
import 'claims_queue_screen.dart';
import 'merchants_screen.dart';
import 'audit_logs_screen.dart';

/// Admin shell with persistent sidebar + top bar + IndexedStack content.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sidebar
        SidebarNav(
          selectedIndex: state.adminTabIndex,
          onTabSelected: (i) => state.setAdminTab(i),
        ),
        // Main content
        Expanded(
          child: Column(
            children: [
              _buildTopBar(context, state),
              Expanded(
                child: IndexedStack(
                  index: state.adminTabIndex,
                  children: const [
                    GlobalDashboardScreen(),
                    ClaimsQueueScreen(),
                    MerchantsScreen(),
                    AuditLogsScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, AppState state) {
    final baseTitles = [
      'Global Operational Overview',
      'Claims Queue',
      'Merchant Management',
      'System Audit Logs'
    ];
    String title = baseTitles[state.adminTabIndex];
    if (state.adminTabIndex == 1 && state.activeMerchantFilter != null) {
      title = '${state.activeMerchantFilter} Claims';
    }
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: VeriServeColors.surfaceContainerLowest,
        border:
            Border(bottom: BorderSide(color: VeriServeColors.outlineVariant)),
      ),
      child: Row(
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontSize: 22)),
          const Spacer(),
          // Search
          SizedBox(
            width: 256,
            height: 36,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                        color: VeriServeColors.outlineVariant)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                        color: VeriServeColors.outlineVariant)),
                filled: true,
                fillColor: VeriServeColors.surfaceContainer,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          // Notifications
          Stack(children: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
                color: VeriServeColors.onSurfaceVariant),
            Positioned(
                top: 8,
                right: 8,
                child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: VeriServeColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1)))),
          ]),
          IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {},
              color: VeriServeColors.onSurfaceVariant),
          const SizedBox(width: 4),
          const CircleAvatar(
              radius: 16,
              backgroundColor: VeriServeColors.primaryContainer,
              child: Text('VS',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
