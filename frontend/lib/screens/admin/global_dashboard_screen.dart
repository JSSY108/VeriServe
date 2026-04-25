import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/veriserve_colors.dart';
import '../../widgets/kpi_card.dart';
import '../../models/claim.dart';

/// Tier 1: Global Operational Overview — Merchant-centric executive dashboard.
class GlobalDashboardScreen extends StatelessWidget {
  const GlobalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final claims = state.claims;
    final resolved =
        claims.where((c) => c.status == ClaimStatus.resolved).length;
    final fraudBlocked =
        claims.where((c) => c.status == ClaimStatus.denied).length;
    final autoRate =
        claims.isEmpty ? 92 : ((resolved / claims.length) * 100).round();

    // Group claims by merchant
    final merchantClaims = <String, List<Claim>>{};
    for (final c in claims) {
      merchantClaims.putIfAbsent(c.merchant, () => []).add(c);
    }
    // Ensure all known merchants appear even if no claims
    for (final m in ['Shopee', 'GrabFood', 'Zalora', 'DHL']) {
      merchantClaims.putIfAbsent(m, () => []);
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
              // ── KPI Row ──
              Row(
                children: [
                  Expanded(
                      child: KpiCard(
                    label: 'Total Verified',
                    value: '${1240 + resolved}',
                    icon: Icons.verified,
                    iconBackground: VeriServeColors.primaryFixed,
                    iconColor: VeriServeColors.deepNavy,
                    trendText: '+12% this week',
                  )),
                  const SizedBox(width: 16),
                  Expanded(
                      child: KpiCard(
                    label: 'Fraud Prevented',
                    value: 'RM 15,200',
                    icon: Icons.shield,
                    iconBackground: VeriServeColors.errorContainer,
                    iconColor: VeriServeColors.onErrorContainer,
                    trendText:
                        'Across ${48 + fraudBlocked} blocked transactions',
                    trendColor: VeriServeColors.onSurfaceVariant,
                  )),
                  const SizedBox(width: 16),
                  Expanded(
                      child: KpiCard(
                    label: 'Auto-Resolution Rate',
                    value: '$autoRate%',
                    icon: Icons.auto_awesome,
                    iconBackground: VeriServeColors.secondaryFixed,
                    iconColor: VeriServeColors.deepNavy,
                    gaugePercent: autoRate.toDouble(),
                  )),
                ],
              ),
              const SizedBox(height: 32),

              // ── Merchant Cards Grid ──
              Text('Merchant Overview',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.65,
                children: merchantClaims.entries
                    .map((e) => _MerchantCard(
                          merchant: e.key,
                          claims: e.value,
                          onTap: () {
                            state.setActiveMerchantFilter(e.key);
                            state.setAdminTab(1);
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MerchantCard extends StatelessWidget {
  final String merchant;
  final List<Claim> claims;
  final VoidCallback onTap;

  const _MerchantCard({
    required this.merchant,
    required this.claims,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _getMerchantVisual(merchant);
    final totalClaims = claims.length;
    final pending =
        claims.where((c) => c.status == ClaimStatus.submitted || c.status == ClaimStatus.ingesting || c.status == ClaimStatus.investigating || c.status == ClaimStatus.auditing).length;
    final escalated =
        claims.where((c) => c.status == ClaimStatus.escalated).length;
    final resolved =
        claims.where((c) => c.status == ClaimStatus.resolved).length;
    final autoResolvePct = totalClaims == 0
        ? 0
        : ((resolved / totalClaims) * 100).round();

    // Build sparkline data: last 7 "periods" based on claim timestamps
    final sparkline = _buildSparkline(claims);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: VeriServeColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VeriServeColors.tertiaryFixed),
          boxShadow: [
            BoxShadow(
                color: VeriServeColors.deepNavy.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Merchant header row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: visual.bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: visual.borderColor),
                  ),
                  child: Icon(visual.icon, size: 22, color: visual.iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(merchant,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 18)),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: VeriServeColors.outline),
              ],
            ),
            const SizedBox(height: 20),

            // Stats row
            Row(
              children: [
                _statBlock('Total Claims', '$totalClaims'),
                const SizedBox(width: 24),
                _statBlock('Pending', '$pending',
                    valueColor: pending > 0
                        ? VeriServeColors.alertOrange
                        : VeriServeColors.successGreen),
                const SizedBox(width: 24),
                _statBlock('Escalated', '$escalated',
                    valueColor: escalated > 0
                        ? VeriServeColors.error
                        : VeriServeColors.successGreen),
                const SizedBox(width: 24),
                _statBlock('Auto Resolve', '$autoResolvePct%',
                    valueColor: autoResolvePct >= 85
                        ? VeriServeColors.successGreen
                        : VeriServeColors.alertOrange),
              ],
            ),
            const SizedBox(height: 16),

            // Sparkline
            Expanded(
              child: CustomPaint(
                painter: _SparklinePainter(
                  data: sparkline,
                  lineColor: visual.iconColor,
                  gradientStart: visual.iconColor.withValues(alpha: 0.25),
                  gradientEnd: visual.iconColor.withValues(alpha: 0.02),
                ),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBlock(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: VeriServeColors.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: valueColor ?? VeriServeColors.onSurface)),
      ],
    );
  }

  /// Build 7-point sparkline from claims grouped by day-of-week.
  List<double> _buildSparkline(List<Claim> claims) {
    if (claims.isEmpty) return [0, 0, 0, 0, 0, 0, 0];
    final counts = List.filled(7, 0.0);
    for (final c in claims) {
      final dow = c.createdAt.weekday; // 1=Mon..7=Sun
      counts[dow % 7] += 1;
    }
    return counts;
  }

  _MerchantVisual _getMerchantVisual(String merchant) {
    switch (merchant) {
      case 'Shopee':
        return const _MerchantVisual(Icons.shopping_bag, Color(0xFFFFF7ED),
            Color(0xFFF97316), Color(0xFFFFEDD5));
      case 'GrabFood':
      case 'Grab':
        return const _MerchantVisual(Icons.restaurant, Color(0xFFF0FDF4),
            Color(0xFF16A34A), Color(0xFFDCFCE7));
      case 'Zalora':
        return const _MerchantVisual(
            Icons.watch, Color(0xFF18181B), Colors.white, Color(0xFF27272A));
      case 'DHL':
        return const _MerchantVisual(Icons.local_shipping, Color(0xFFFFCC00),
            Color(0xFFD40511), Color(0xFFFFD633));
      default:
        return const _MerchantVisual(
            Icons.store,
            VeriServeColors.surfaceContainer,
            VeriServeColors.onSurface,
            VeriServeColors.outlineVariant);
    }
  }
}

/// Custom painter for a sparkline chart with gradient fill.
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color gradientStart;
  final Color gradientEnd;

  _SparklinePainter({
    required this.data,
    required this.lineColor,
    required this.gradientStart,
    required this.gradientEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.width <= 0 || size.height <= 0) return;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return;

    final dx = size.width / (data.length - 1).clamp(1, 999);

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height - (data[i] / maxVal) * size.height * 0.9;
      points.add(Offset(x, y));
    }

    // Gradient fill
    final fillPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final cp = Offset(
        (points[i - 1].dx + points[i].dx) / 2,
        points[i - 1].dy,
      );
      final cp2 = Offset(
        (points[i - 1].dx + points[i].dx) / 2,
        points[i].dy,
      );
      fillPath.cubicTo(cp.dx, cp.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.lineTo(points.first.dx, size.height);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [gradientStart, gradientEnd],
    );
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = gradient.createShader(
            Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // Line
    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final cp = Offset(
        (points[i - 1].dx + points[i].dx) / 2,
        points[i - 1].dy,
      );
      final cp2 = Offset(
        (points[i - 1].dx + points[i].dx) / 2,
        points[i].dy,
      );
      linePath.cubicTo(cp.dx, cp.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Dots
    for (final p in points) {
      canvas.drawCircle(p, 3, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      data != oldDelegate.data;
}

class _MerchantVisual {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final Color borderColor;
  const _MerchantVisual(
      this.icon, this.bgColor, this.iconColor, this.borderColor);
}
