import 'package:flutter/material.dart';
import '../theme/veriserve_colors.dart';

/// Persistent sidebar navigation for the Admin SaaS interface.
class SidebarNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const SidebarNav({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  static const _navItems = [
    _NavItem(icon: Icons.radar, label: 'Overview'),
    _NavItem(icon: Icons.policy, label: 'Investigations'),
    _NavItem(icon: Icons.hub, label: 'Merchants'),
    _NavItem(icon: Icons.receipt_long, label: 'Audit Logs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: VeriServeColors.surfaceContainerLowest,
        border: Border(
          right: BorderSide(color: VeriServeColors.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // ── Brand Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: VeriServeColors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'VS',
                    style: TextStyle(
                      color: VeriServeColors.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VeriServe Ops',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 18, letterSpacing: -0.5),
                    ),
                    Text(
                      'Verified Environment',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: VeriServeColors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),


          // ── Nav Items ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: List.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  final isActive = selectedIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onTabSelected(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? VeriServeColors.surfaceContainerLowest
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isActive
                                ? const Border(
                                    right: BorderSide(
                                      color: VeriServeColors.deepNavy,
                                      width: 2,
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 20,
                                color: isActive
                                    ? VeriServeColors.onSurface
                                    : VeriServeColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isActive
                                      ? VeriServeColors.onSurface
                                      : VeriServeColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // ── Bottom Section ──
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: VeriServeColors.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: const Column(
              children: [
                _BottomNavItem(icon: Icons.contact_support, label: 'Support'),
                _BottomNavItem(icon: Icons.settings, label: 'Settings'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BottomNavItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: VeriServeColors.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: VeriServeColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
