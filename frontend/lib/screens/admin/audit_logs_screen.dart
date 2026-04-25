import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/veriserve_colors.dart';
import '../../widgets/status_badge.dart';
import '../../models/claim.dart';

/// System Audit Logs — chronological log of all system events.
class AuditLogsScreen extends StatelessWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final claims = state.claims;

    return Container(
      color: VeriServeColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              const Icon(Icons.history_edu,
                  color: VeriServeColors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('System Audit Trail',
                  style: Theme.of(context).textTheme.headlineLarge),
              const Spacer(),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: VeriServeColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: VeriServeColors.outlineVariant)),
                  child: const Row(children: [
                    Icon(Icons.filter_list,
                        size: 16, color: VeriServeColors.onSurfaceVariant),
                    SizedBox(width: 8),
                    Text('Filter',
                        style: TextStyle(
                            fontSize: 14,
                            color: VeriServeColors.onSurfaceVariant)),
                  ])),
            ]),
            const SizedBox(height: 24),

            // Log table
            Container(
              decoration: BoxDecoration(
                color: VeriServeColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VeriServeColors.outlineVariant),
              ),
              child: Column(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(
                    color: VeriServeColors.surfaceContainerLow,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  child: Row(children: [
                    _h('TIMESTAMP', 2),
                    _h('EVENT', 3),
                    _h('CLAIM', 2),
                    _h('AGENT', 2),
                    _h('STATUS', 2),
                  ]),
                ),
                ...claims.map((c) => _row(c)),
                // Static historical entries
                _staticRow(
                    '10:14:22',
                    'Policy updated: auto_refund_threshold → RM 50.00',
                    'SHOPEE_ID_882',
                    'System',
                    'Completed'),
                _staticRow(
                    '09:58:01',
                    'New merchant onboarded: Lazada (LZ_ID_501)',
                    '-',
                    'Admin',
                    'Completed'),
                _staticRow(
                    '09:42:18',
                    'Vision model retrained on 1,240 new samples',
                    '-',
                    'MLOps',
                    'Completed'),
              ]),
            ),
          ]),
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

  Widget _row(Claim c) {
    final time =
        '${c.createdAt.hour.toString().padLeft(2, '0')}:${c.createdAt.minute.toString().padLeft(2, '0')}:${c.createdAt.second.toString().padLeft(2, '0')}';
    final event = c.status == ClaimStatus.resolved
        ? 'Claim auto-resolved: ${c.orderId} (${c.confidence?.toStringAsFixed(1)}%)'
        : 'Claim submitted: ${c.orderId} — ${c.category}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: VeriServeColors.tertiaryFixed)),
      ),
      child: Row(children: [
        Expanded(
            flex: 2,
            child: Text(time,
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    color: VeriServeColors.onSurfaceVariant))),
        Expanded(
            flex: 3, child: Text(event, style: const TextStyle(fontSize: 14))),
        Expanded(
            flex: 2,
            child: Text('#${c.orderId}',
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: VeriServeColors.onSurfaceVariant))),
        Expanded(
            flex: 2,
            child: Text(_agentForStatus(c.status),
                style: const TextStyle(
                    fontSize: 14, color: VeriServeColors.onSurfaceVariant))),
        Expanded(flex: 2, child: StatusBadge(status: c.status, humanVerified: c.humanVerified)),
      ]),
    );
  }

  Widget _staticRow(
      String time, String event, String ref, String agent, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: VeriServeColors.tertiaryFixed)),
      ),
      child: Row(children: [
        Expanded(
            flex: 2,
            child: Text(time,
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    color: VeriServeColors.onSurfaceVariant))),
        Expanded(
            flex: 3, child: Text(event, style: const TextStyle(fontSize: 14))),
        Expanded(
            flex: 2,
            child: Text(ref,
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: VeriServeColors.onSurfaceVariant))),
        Expanded(
            flex: 2,
            child: Text(agent,
                style: const TextStyle(
                    fontSize: 14, color: VeriServeColors.onSurfaceVariant))),
        Expanded(
            flex: 2,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0))),
                child: Text(status,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: VeriServeColors.successGreen)))),
      ]),
    );
  }

  String _agentForStatus(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.submitted:
        return 'System';
      case ClaimStatus.ingesting:
        return 'Ingestor';
      case ClaimStatus.investigating:
        return 'Investigator';
      case ClaimStatus.auditing:
        return 'Auditor';
      case ClaimStatus.resolved:
        return 'Auditor';
      case ClaimStatus.denied:
        return 'Auditor';
      case ClaimStatus.escalated:
        return 'System';
    }
  }
}
