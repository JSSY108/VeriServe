import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/veriserve_colors.dart';
import '../../widgets/confidence_gauge.dart';
import '../../widgets/reasoning_trace.dart';
import '../../models/claim.dart';

/// Tier 3: Deep-Dive Audit Dashboard — Ingestor + Visual Evidence + Reasoning Trace + Auditor Verdict.
class AuditDeepDiveScreen extends StatefulWidget {
  final String claimId;
  const AuditDeepDiveScreen({super.key, required this.claimId});

  @override
  State<AuditDeepDiveScreen> createState() => _AuditDeepDiveScreenState();
}

class _AuditDeepDiveScreenState extends State<AuditDeepDiveScreen> {
  AuditTrace? _fetchedTrace;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrace();
  }

  Future<void> _loadTrace() async {
    final state = context.read<AppState>();
    final claim = state.claims.where((c) => c.id == widget.claimId).firstOrNull;
    if (claim?.auditTrace != null) {
      setState(() {
        _fetchedTrace = claim!.auditTrace;
        _loading = false;
      });
      return;
    }
    try {
      final trace = await state.apiService.getAuditTrace(widget.claimId);
      if (mounted) {
        setState(() {
          _fetchedTrace = trace;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final claim = state.claims.where((c) => c.id == widget.claimId).firstOrNull ??
        (state.claims.isNotEmpty ? state.claims.first : _demoClaim());
    final trace = _fetchedTrace ?? claim.auditTrace;

    return Scaffold(
      backgroundColor: VeriServeColors.background,
      appBar: AppBar(
        title: Text('Claim #${claim.orderId}'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Context Header
            _buildContextHeader(context, claim),
            const SizedBox(height: 32),

            // Split layout
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Left column (7/12)
              Expanded(
                  flex: 7,
                  child: Column(children: [
                    if (trace != null) _buildIngestorWidget(context, trace, claim),
                    const SizedBox(height: 16),
                    _buildAgentHandoff(),
                    const SizedBox(height: 16),
                    _buildVisualEvidence(context, claim),
                  ])),
              const SizedBox(width: 32),
              // Right column (5/12)
              Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 600,
                    child: ReasoningTrace(
                      steps: trace?.reasoningLog ?? [],
                      onApprove: () => state.approveClaim(widget.claimId),
                      onFlag: () {},
                    ),
                  )),
            ]),
            const SizedBox(height: 32),

            // Auditor Verdict
            if (trace != null) _buildAuditorVerdict(context, trace, claim, state),
          ]),
        ),
      ),
    );
  }

  Widget _buildContextHeader(BuildContext context, Claim claim) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: VeriServeColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VeriServeColors.outlineVariant)),
              child: Text('Merchant: ${claim.merchant}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: VeriServeColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VeriServeColors.outlineVariant)),
              child: Text('Category: ${claim.category}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: VeriServeColors.onSurfaceVariant))),
        ]),
        const SizedBox(height: 8),
        Text('Claim #${claim.orderId}',
            style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 4),
        Text(claim.description.isNotEmpty ? claim.description : 'No description',
            style: const TextStyle(
                fontSize: 16, color: VeriServeColors.onSurfaceVariant)),
      ]),
      ConfidenceGauge(
          percentage: claim.confidence ?? 0, label: 'Veracity Confidence'),
    ]);
  }

  Widget _buildIngestorWidget(BuildContext context, AuditTrace trace, Claim claim) {
    return Container(
      decoration: BoxDecoration(
          color: VeriServeColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VeriServeColors.outlineVariant)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: VeriServeColors.surfaceContainerLow,
            borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            border: Border(bottom: BorderSide(color: VeriServeColors.outlineVariant)),
          ),
          child: Row(children: [
            const Icon(Icons.data_exploration, size: 18, color: VeriServeColors.onSurfaceVariant),
            const SizedBox(width: 8),
            Text('Ingestor Analysis',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18)),
            const Spacer(),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: VeriServeColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Module: NLP-Ingest-2.4',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        letterSpacing: 0.6, color: VeriServeColors.onSurfaceVariant))),
          ]),
        ),
        IntrinsicHeight(
            child: Row(children: [
          Expanded(
              child: Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFFDFAF1),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.chat_bubble, size: 14, color: VeriServeColors.onSurfaceVariant),
                SizedBox(width: 4),
                Text('ORIGINAL COMPLAINT',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        letterSpacing: 0.6, color: VeriServeColors.onSurfaceVariant)),
              ]),
              const SizedBox(height: 12),
              _HighlightedComplaint(
                text: '"${claim.description}"',
                damageType: trace.ingestorResult.damageType,
                sentiment: trace.ingestorResult.sentiment,
                intent: trace.ingestorResult.intent,
              ),
            ]),
          )),
          Container(width: 1, color: VeriServeColors.outlineVariant),
          Expanded(
              child: ClipRRect(
            child: Stack(children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF0F4F8), Color(0xFFE6EEF5), Color(0xFFEEF2FF)],
                    ),
                  ),
                ),
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.storage, size: 14, color: VeriServeColors.onSurfaceVariant),
                      SizedBox(width: 4),
                      Text('INGESTOR EXTRACTIONS',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              letterSpacing: 0.6, color: VeriServeColors.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 12),
                    _ExtractionRow(
                      icon: Icons.radar,
                      label: 'Intent:',
                      value: '[${trace.ingestorResult.intent}] ${(trace.ingestorResult.confidence * 100).toStringAsFixed(0)}% Confidence',
                      bg: VeriServeColors.primaryContainer,
                      fg: VeriServeColors.onPrimaryContainer,
                      animType: _ExtractionAnimType.pulse,
                    ),
                    const SizedBox(height: 8),
                    _ExtractionRow(
                      icon: Icons.warning_amber_rounded,
                      label: 'Damage Type:',
                      value: '[${trace.ingestorResult.damageType.isNotEmpty ? trace.ingestorResult.damageType : "Physical Damage"}]',
                      bg: VeriServeColors.secondaryContainer,
                      fg: VeriServeColors.onSecondaryContainer,
                      animType: _ExtractionAnimType.shake,
                    ),
                    const SizedBox(height: 8),
                    _ExtractionRow(
                      icon: Icons.monitor_heart,
                      label: 'Sentiment:',
                      value: '[${trace.ingestorResult.sentiment}]',
                      bg: VeriServeColors.errorContainer,
                      fg: VeriServeColors.onErrorContainer,
                      animType: _ExtractionAnimType.heartbeat,
                    ),
                  ]),
                ),
              ),
            ]),
          )),
        ])),
      ]),
    );
  }

  Widget _buildAgentHandoff() {
    return const _DataStreamConnector();
  }

  Widget _buildVisualEvidence(BuildContext context, Claim claim) {
    final podUrl = claim.riderPodUrl;
    final custUrl = claim.evidenceUrls.firstOrNull;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: VeriServeColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VeriServeColors.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.compare,
              size: 18, color: VeriServeColors.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('Visual Evidence',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 18)),
          const Spacer(),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: VeriServeColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Delta Analysis',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: VeriServeColors.onSurfaceVariant))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: _evidenceCard(
                  'Rider PoD (T-0)', Icons.local_shipping, false, podUrl)),
          const SizedBox(width: 16),
          Expanded(
              child: _evidenceCard(
                  'Customer Upload (T+1h)', Icons.warning, true, custUrl)),
        ]),
      ]),
    );
  }

  Widget _evidenceCard(String label, IconData icon, bool isDamage, String? imageUrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon,
            size: 14,
            color: isDamage
                ? VeriServeColors.error
                : VeriServeColors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: isDamage
                    ? VeriServeColors.error
                    : VeriServeColors.onSurfaceVariant)),
      ]),
      const SizedBox(height: 8),
      AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: VeriServeColors.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isDamage
                    ? VeriServeColors.error.withValues(alpha: 0.5)
                    : VeriServeColors.outlineVariant,
                width: isDamage ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl != null && imageUrl.startsWith('http')
              ? Stack(fit: StackFit.expand, children: [
                  Image.network(imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                          child: Icon(isDamage ? Icons.broken_image : Icons.image,
                              size: 48, color: VeriServeColors.outlineVariant))),
                  if (isDamage)
                    Positioned(
                        top: 16,
                        left: 16,
                        right: 64,
                        bottom: 64,
                        child: Container(
                            decoration: BoxDecoration(
                                border: Border.all(color: VeriServeColors.error),
                                borderRadius: BorderRadius.circular(4),
                                color: VeriServeColors.error.withValues(alpha: 0.1)))),
                ])
              : Stack(children: [
                  Center(
                      child: Icon(isDamage ? Icons.broken_image : Icons.image,
                          size: 48, color: VeriServeColors.outlineVariant)),
                  if (isDamage)
                    Positioned(
                        top: 16,
                        left: 16,
                        right: 64,
                        bottom: 64,
                        child: Container(
                            decoration: BoxDecoration(
                                border: Border.all(color: VeriServeColors.error),
                                borderRadius: BorderRadius.circular(4),
                                color: VeriServeColors.error.withValues(alpha: 0.1)))),
                ]),
        ),
      ),
    ]);
  }

  Widget _buildAuditorVerdict(
      BuildContext context, AuditTrace trace, Claim claim, AppState state) {
    return Container(
      decoration: BoxDecoration(
          color: VeriServeColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VeriServeColors.deepNavy, width: 2),
          boxShadow: [
            BoxShadow(
                color: VeriServeColors.deepNavy.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ]),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
              color: VeriServeColors.deepNavy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
          child: Row(children: [
            const Icon(Icons.gavel, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('[Auditor Agent] Final Policy Review',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: Colors.white, fontSize: 18)),
            const Spacer(),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Policy v4.2-Secure',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: Colors.white))),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.all(24),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Compliance checks
              Expanded(
                  child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: VeriServeColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: VeriServeColors.outlineVariant)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('COMPLIANCE CHECKLIST',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              color: VeriServeColors.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      ...trace.complianceChecks.map((check) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                        color: Color(0xFFDCFCE7),
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.check,
                                        size: 18, color: Color(0xFF16A34A))),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(check.label,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text(check.detail,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: VeriServeColors
                                                  .onSurfaceVariant)),
                                    ])),
                              ]))),
                    ]),
              )),
              const SizedBox(width: 32),
              // Verdict box
              Expanded(
                  child: Center(
                      child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    border:
                        Border.all(color: VeriServeColors.deepNavy, width: 4),
                    borderRadius: BorderRadius.circular(12),
                    color: VeriServeColors.deepNavy.withValues(alpha: 0.05)),
                child: Column(children: [
                  Icon(claim.humanVerified ? Icons.verified_user_rounded : Icons.verified_user,
                      size: 36, color: VeriServeColors.deepNavy),
                  const SizedBox(height: 8),
                  Text('VERDICT: ${trace.verdict.toUpperCase()}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: VeriServeColors.deepNavy,
                          letterSpacing: -0.3),
                      textAlign: TextAlign.center),
                  Container(
                      height: 1,
                      width: 96,
                      color: VeriServeColors.deepNavy.withValues(alpha: 0.3),
                      margin: const EdgeInsets.symmetric(vertical: 12)),
                  Text(
                      claim.humanVerified
                          ? 'Verified by human review. Payment disbursed by admin.'
                          : claim.status == ClaimStatus.resolved
                              ? 'Autonomously approved. Payment API executed.'
                              : 'Final findings satisfy all Merchant-defined risk parameters and regional policy constraints.',
                      style: const TextStyle(
                          fontSize: 14,
                          color: VeriServeColors.onSurface,
                          height: 1.5),
                      textAlign: TextAlign.center),
                ]),
              ))),
            ])),
        // Execute CTA
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(children: [
            Container(
                height: 40,
                width: 1,
                color: VeriServeColors.deepNavy.withValues(alpha: 0.3)),
            const Icon(Icons.arrow_drop_down,
                color: VeriServeColors.deepNavy, size: 32),
            const SizedBox(height: 8),
            SizedBox(
                width: 400,
                child: ElevatedButton(
                  onPressed: claim.status == ClaimStatus.resolved ? null : () => state.approveClaim(widget.claimId),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20)),
                  child: Column(children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(claim.status == ClaimStatus.resolved ? Icons.check_circle : Icons.account_balance_wallet, size: 20),
                          const SizedBox(width: 8),
                          Text(claim.status == ClaimStatus.resolved ? 'Payment Executed' : 'Execute Payment API',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                        ]),
                    const SizedBox(height: 4),
                    Text(claim.status == ClaimStatus.resolved ? 'DISBURSEMENT COMPLETE' : 'INSTANT DISBURSEMENT VIA VERACITY-NET',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.2,
                            color: Colors.white.withValues(alpha: 0.7))),
                  ]),
                )),
          ]),
        ),
      ]),
    );
  }

  Claim _demoClaim() => Claim(
      id: 'demo',
      orderId: 'SHP-992',
      merchant: 'Shopee',
      category: 'Electronics',
      description: '',
      createdAt: DateTime.now(),
      confidence: 98.42);
}

// ─── Highlighted Complaint ────────────────────────────────────────────────────

class _HighlightedComplaint extends StatelessWidget {
  final String text;
  final String damageType;
  final String sentiment;
  final String intent;
  const _HighlightedComplaint(
      {required this.text, required this.damageType, required this.sentiment, required this.intent});

  List<TextSpan> _buildSpans() {
    final keywords = <String, Color>{};
    for (final w in damageType.toLowerCase().split(RegExp(r'\s+'))) {
      if (w.length > 2) keywords[w] = const Color(0xFFBA1A1A);
    }
    for (final w in sentiment.toLowerCase().split(RegExp(r'\s+'))) {
      if (w.length > 2) keywords[w] = const Color(0xFFF59E0B);
    }
    for (final w in intent.toLowerCase().split(RegExp(r'\s+'))) {
      if (w.length > 2) keywords[w] = const Color(0xFF2563EB);
    }
    if (keywords.isEmpty) return [TextSpan(text: text)];
    final pattern = '(${keywords.keys.map(RegExp.escape).join('|')})';
    final regex = RegExp(pattern, caseSensitive: false);
    final spans = <TextSpan>[];
    int last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final color = keywords[m.group(0)!.toLowerCase()]!;
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          backgroundColor: color.withValues(alpha: 0.12),
        ),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, height: 1.6, color: Color(0xFF1B1B1D)),
        children: _buildSpans(),
      ),
    );
  }
}

// ─── Extraction Row ───────────────────────────────────────────────────────────

enum _ExtractionAnimType { pulse, shake, heartbeat }

class _ExtractionRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color bg;
  final Color fg;
  final _ExtractionAnimType animType;
  const _ExtractionRow(
      {required this.icon, required this.label, required this.value,
       required this.bg, required this.fg, required this.animType});
  @override
  State<_ExtractionRow> createState() => _ExtractionRowState();
}

class _ExtractionRowState extends State<_ExtractionRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    final dur = widget.animType == _ExtractionAnimType.heartbeat
        ? const Duration(milliseconds: 600)
        : const Duration(milliseconds: 1800);
    _ctrl = AnimationController(vsync: this, duration: dur)..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            double scale = 1.0;
            double dx = 0;
            if (widget.animType == _ExtractionAnimType.pulse ||
                widget.animType == _ExtractionAnimType.heartbeat) {
              scale = 1.0 + _ctrl.value * 0.25;
            } else {
              dx = math.sin(_ctrl.value * math.pi * 4) * 2.5;
            }
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: Icon(widget.icon, size: 16, color: widget.fg),
        ),
        const SizedBox(width: 8),
        Text(widget.label,
            style: const TextStyle(fontSize: 14, color: VeriServeColors.onSurfaceVariant)),
      ]),
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: widget.bg, borderRadius: BorderRadius.circular(8)),
          child: Text(widget.value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: widget.fg))),
    ]);
  }
}

// ─── Data Stream Connector ────────────────────────────────────────────────────

class _DataStreamConnector extends StatefulWidget {
  const _DataStreamConnector();
  @override
  State<_DataStreamConnector> createState() => _DataStreamConnectorState();
}

class _DataStreamConnectorState extends State<_DataStreamConnector>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Stack(alignment: Alignment.center, children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            size: const Size(double.infinity, 60),
            painter: _DataStreamPainter(progress: _ctrl.value),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: VeriServeColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VeriServeColors.outlineVariant),
          ),
          child: const Text(
            'INGESTOR DATA PASSED TO INVESTIGATOR AGENT FOR VISION DELTA ANALYSIS...',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                letterSpacing: 0.8, color: VeriServeColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }
}

class _DataStreamPainter extends CustomPainter {
  final double progress;
  _DataStreamPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const dashH = 8.0, gap = 5.0, pattern = dashH + gap;
    final cx = size.width / 2;
    final offset = progress * pattern;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF58A6FF), Color(0xFF00CFFF)],
      ).createShader(Rect.fromLTWH(cx - 1, 0, 2, size.height));
    double y = -pattern + offset;
    while (y < size.height) {
      final s = y.clamp(0.0, size.height);
      final e = (y + dashH).clamp(0.0, size.height);
      if (e > s) canvas.drawLine(Offset(cx, s), Offset(cx, e), paint);
      y += pattern;
    }
  }

  @override
  bool shouldRepaint(_DataStreamPainter old) => old.progress != progress;
}
