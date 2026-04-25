import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/veriserve_colors.dart';
import '../../widgets/status_badge.dart';
import '../../models/claim.dart';
import 'audit_deep_dive_screen.dart';

/// Tier 2: Claims Queue — filterable table with merchant deep-link support.
class ClaimsQueueScreen extends StatelessWidget {
  const ClaimsQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final activeFilter = state.activeMerchantFilter;

    // Apply merchant filter if set from Dashboard deep-link
    List<Claim> claims = state.claims;
    if (activeFilter != null) {
      claims = claims.where((c) => c.merchant == activeFilter).toList();
    }

    return Container(
      color: VeriServeColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb / filter context
              if (activeFilter != null) ...[
                _FilterBanner(
                  merchant: activeFilter,
                  onClear: () => state.clearMerchantFilter(),
                  onBack: () {
                    state.clearMerchantFilter();
                    state.setAdminTab(0);
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Filter chips
              Wrap(spacing: 8, children: [
                _FilterChip(
                    label: 'All',
                    selected: activeFilter == null,
                    onSelected: (_) => state.clearMerchantFilter()),
                _FilterChip(
                    label: 'Shopee',
                    selected: activeFilter == 'Shopee',
                    onSelected: (_) =>
                        state.setActiveMerchantFilter('Shopee')),
                _FilterChip(
                    label: 'GrabFood',
                    selected: activeFilter == 'GrabFood',
                    onSelected: (_) =>
                        state.setActiveMerchantFilter('GrabFood')),
                _FilterChip(
                    label: 'Zalora',
                    selected: activeFilter == 'Zalora',
                    onSelected: (_) =>
                        state.setActiveMerchantFilter('Zalora')),
                _FilterChip(
                    label: 'DHL',
                    selected: activeFilter == 'DHL',
                    onSelected: (_) =>
                        state.setActiveMerchantFilter('DHL')),
              ]),
              const SizedBox(height: 24),

              // Claims table
              Container(
                decoration: BoxDecoration(
                  color: VeriServeColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VeriServeColors.outlineVariant),
                ),
                child: Column(children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    decoration: const BoxDecoration(
                      color: VeriServeColors.surfaceContainerLow,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(11)),
                    ),
                    child: Row(children: [
                      _h('ORDER ID', 2),
                      _h('MERCHANT', 2),
                      _h('CATEGORY', 2),
                      _h('AMOUNT', 1),
                      _h('CONFIDENCE', 1),
                      _h('STATUS', 2),
                      _h('ACTION', 1),
                    ]),
                  ),
                  // Rows
                  if (claims.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          activeFilter != null
                              ? 'No claims found for $activeFilter'
                              : 'No claims yet',
                          style: const TextStyle(
                              color: VeriServeColors.onSurfaceVariant,
                              fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ...claims.map((c) => _row(context, c, state)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _h(String t, int flex) => Expanded(
      flex: flex,
      child: Text(t,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: VeriServeColors.onSurfaceVariant)));

  Widget _row(BuildContext context, Claim c, AppState state) {
    return InkWell(
      onTap: () {
        state.setActiveClaim(c.id);
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AuditDeepDiveScreen(claimId: c.id)));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: VeriServeColors.tertiaryFixed)),
        ),
        child: Row(children: [
          Expanded(
              flex: 2,
              child: Text('#${c.orderId}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      color: VeriServeColors.onSurfaceVariant))),
          Expanded(
              flex: 2,
              child: Text(c.merchant,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
              flex: 2,
              child: Text(c.category,
                  style: const TextStyle(
                      color: VeriServeColors.onSurfaceVariant))),
          Expanded(
              flex: 1,
              child: Text(
                  c.claimAmount != null
                      ? 'RM ${c.claimAmount!.toStringAsFixed(2)}'
                      : '-',
                  style: const TextStyle(fontSize: 14))),
          Expanded(
              flex: 1,
              child: Text(
                  c.confidence != null
                      ? '${(c.confidence! * 100).toStringAsFixed(1)}%'
                      : '—',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: (c.confidence ?? 0) > 0.90
                          ? VeriServeColors.successGreen
                          : VeriServeColors.alertOrange))),
          Expanded(flex: 2, child: StatusBadge(status: c.status, humanVerified: c.humanVerified)),
          const Expanded(
              flex: 1,
              child: Icon(Icons.arrow_forward_ios,
                  size: 14, color: VeriServeColors.outline)),
        ]),
      ),
    );
  }
}

/// Filter context banner shown when deep-linked from Dashboard.
class _FilterBanner extends StatelessWidget {
  final String merchant;
  final VoidCallback onClear;
  final VoidCallback onBack;

  const _FilterBanner({
    required this.merchant,
    required this.onClear,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: VeriServeColors.secondaryFixed.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VeriServeColors.secondaryFixedDim),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            child: const Row(children: [
              Icon(Icons.arrow_back, size: 16, color: VeriServeColors.secondary),
              SizedBox(width: 4),
              Text('Back to Overview',
                  style: TextStyle(
                      color: VeriServeColors.secondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          const SizedBox(width: 16),
          Icon(Icons.filter_alt, size: 16, color: VeriServeColors.deepNavy.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text('Filtered: $merchant',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: VeriServeColors.deepNavy)),
          const Spacer(),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Row(children: [
              Icon(Icons.clear, size: 14, color: VeriServeColors.secondary),
              SizedBox(width: 4),
              Text('Clear Filter',
                  style: TextStyle(
                      color: VeriServeColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Styled filter chip that integrates with AppState.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: VeriServeColors.primaryFixed,
      checkmarkColor: VeriServeColors.deepNavy,
    );
  }
}
