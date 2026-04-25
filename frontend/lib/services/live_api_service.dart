import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/claim.dart';
import '../models/merchant_policy.dart';
import 'api_service.dart';

class LiveApiService implements ApiService {
  final String baseUrl;
  final http.Client _client;

  LiveApiService({this.baseUrl = 'http://localhost:8000'})
      : _client = http.Client();

  // ── Claim Status Mapping ──

  static ClaimStatus _mapStatus(String backendStatus) {
    switch (backendStatus) {
      // Raw backend statuses (from orchestrate response)
      case 'refunded':
        return ClaimStatus.resolved;
      case 'manual_review':
        return ClaimStatus.escalated;
      case 'fraud_rejected':
        return ClaimStatus.denied;
      case 'pending':
        return ClaimStatus.submitted;
      // Frontend-mapped statuses (from GET /api/claims)
      case 'resolved':
        return ClaimStatus.resolved;
      case 'escalated':
        return ClaimStatus.escalated;
      case 'denied':
        return ClaimStatus.denied;
      case 'submitted':
        return ClaimStatus.submitted;
      default:
        return ClaimStatus.submitted;
    }
  }

  static RiskLevel _mapRisk(double? confidence) {
    if (confidence == null) return RiskLevel.medium;
    if (confidence >= 0.85) return RiskLevel.low;
    if (confidence >= 0.50) return RiskLevel.medium;
    return RiskLevel.high;
  }

  // ── POST /api/orchestrate ──

  @override
  Future<Claim> submitClaim(Claim claim) async {
    // Parse order_id — strip non-digits and parse int
    final orderIdStr = claim.orderId.replaceAll(RegExp(r'[^0-9]'), '');
    final orderId = int.tryParse(orderIdStr) ?? 1;

    final body = jsonEncode({
      'order_id': orderId,
      'user_category_selection': claim.category,
      'complaint_text': claim.description,
      'customer_image_url':
          claim.evidenceUrls.isNotEmpty ? claim.evidenceUrls.first : '',
    });

    final response = await _client.post(
      Uri.parse('$baseUrl/api/orchestrate'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Orchestrate failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final decision = data['glm_decision'] as Map<String, dynamic>;
    final traceLog = (decision['trace_log'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    final finalAction = decision['final_action'] as String? ?? 'MANUAL_ESCALATION';
    final confidenceScore = (decision['confidence_score'] as num?)?.toDouble() ?? 0.0;

    // Map final_action to ClaimStatus
    ClaimStatus status;
    switch (finalAction) {
      case 'APPROVE_REFUND':
        status = ClaimStatus.resolved;
        break;
      case 'REJECT_FRAUD':
        status = ClaimStatus.denied;
        break;
      default:
        status = ClaimStatus.escalated;
    }

    // Build AuditTrace from GLM decision
    var auditTrace = _buildTraceFromGlm(traceLog, finalAction, confidenceScore);

    // Add Payment API step for auto-approved claims
    if (status == ClaimStatus.resolved) {
      final steps = List<AgentTraceStep>.from(auditTrace.reasoningLog);
      steps.add(AgentTraceStep(
        lineNumber: steps.length + 1,
        agent: 'System',
        content: '> Payment API executed — refund disbursed automatically',
        isCritical: false,
      ));
      auditTrace = AuditTrace(
        ingestorResult: auditTrace.ingestorResult,
        investigatorConfidence: auditTrace.investigatorConfidence,
        investigatorSummary: auditTrace.investigatorSummary,
        complianceChecks: auditTrace.complianceChecks,
        verdict: auditTrace.verdict,
        reasoningLog: steps,
      );
    }

    return Claim(
      id: 'CLM-${(data['ticket_id'] as int).toString().padLeft(3, '0')}',
      orderId: claim.orderId,
      merchant: claim.merchant,
      category: claim.category,
      description: claim.description,
      evidenceUrls: claim.evidenceUrls,
      status: status,
      riskLevel: _mapRisk(data['vision_match_score'] as double?),
      confidence: data['vision_match_score'] as double?,
      auditTrace: auditTrace,
      createdAt: claim.createdAt,
      resolvedAt: DateTime.now(),
      claimAmount: claim.claimAmount,
      riderPodUrl: data['rider_pod_url'] as String? ?? claim.riderPodUrl,
    );
  }

  AuditTrace _buildTraceFromGlm(
    List<Map<String, dynamic>> traceLog,
    String finalAction,
    double confidence,
  ) {
    // Extract per-agent results
    String intent = 'Review';
    String damageType = '';
    String sentiment = 'Neutral';
    double ingestorConf = confidence;
    String investigatorSummary = '';
    List<ComplianceCheck> checks = [];
    List<AgentTraceStep> reasoning = [];

    for (int i = 0; i < traceLog.length; i++) {
      final entry = traceLog[i];
      final agent = entry['agent'] as String? ?? 'System';
      final result = entry['result'] as String? ?? '';
      final action = entry['action'] as String? ?? '';

      // Reasoning log
      reasoning.add(AgentTraceStep(
        lineNumber: i + 1,
        agent: agent,
        content: '> $result',
        isCritical: result.toLowerCase().contains('mismatch') ||
            result.toLowerCase().contains('fraud'),
      ));

      // Per-agent extraction
      if (agent == 'Ingestor') {
        intent = result.toLowerCase().contains('refund') ? 'Refund' : 'Review';
        damageType = action;
        sentiment = result.toLowerCase().contains('urgent') ? 'Urgent' : 'Neutral';
      } else if (agent == 'Investigator') {
        investigatorSummary = result;
      } else if (agent == 'Auditor') {
        checks.add(ComplianceCheck(
          label: action,
          detail: result,
          passed: finalAction != 'REJECT_FRAUD',
        ));
      }
    }

    String verdict;
    if (finalAction == 'APPROVE_REFUND') {
      verdict = 'Autonomous Approval';
    } else if (finalAction == 'REJECT_FRAUD') {
      verdict = 'Fraud Rejected';
    } else {
      verdict = 'Manual Escalation';
    }

    return AuditTrace(
      ingestorResult: IngestorExtraction(
        intent: intent,
        damageType: damageType,
        sentiment: sentiment,
        confidence: ingestorConf,
      ),
      investigatorConfidence: confidence,
      investigatorSummary: investigatorSummary,
      complianceChecks: checks,
      verdict: verdict,
      reasoningLog: reasoning,
    );
  }

  // ── GET /api/claims ──

  @override
  Future<List<Claim>> getClaims({String? merchantFilter}) async {
    var uri = Uri.parse('$baseUrl/api/claims');
    if (merchantFilter != null) {
      uri = uri.replace(queryParameters: {'merchant': merchantFilter});
    }

    final response = await _client.get(uri, headers: {'Content-Type': 'application/json'});
    if (response.statusCode != 200) {
      throw Exception('Get claims failed: ${response.statusCode}');
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => _mapClaim(e as Map<String, dynamic>)).toList();
  }

  Claim _mapClaim(Map<String, dynamic> m) {
    return Claim(
      id: m['id'] as String? ?? '',
      orderId: m['orderId'] as String? ?? '',
      merchant: m['merchant'] as String? ?? 'Unknown',
      category: m['category'] as String? ?? 'General',
      description: m['description'] as String? ?? '',
      evidenceUrls: (m['evidenceUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      status: _mapStatus(m['status'] as String? ?? 'pending'),
      riskLevel: _mapRisk((m['confidence'] as num?)?.toDouble()),
      confidence: (m['confidence'] as num?)?.toDouble(),
      claimAmount: (m['claimAmount'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
          DateTime.now(),
      resolvedAt: m['resolvedAt'] != null
          ? DateTime.tryParse(m['resolvedAt'] as String)
          : null,
      riderPodUrl: m['riderPodUrl'] as String?,
    );
  }

  // ── GET /api/claims/{id}/trace ──

  @override
  Future<AuditTrace> getAuditTrace(String claimId) async {
    // claimId is "CLM-001" format — extract numeric id
    final numPart = claimId.replaceAll(RegExp(r'[^0-9]'), '');
    final ticketId = int.tryParse(numPart) ?? 1;

    final response = await _client.get(
      Uri.parse('$baseUrl/api/claims/$ticketId/trace'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Get trace failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _mapAuditTrace(data);
  }

  AuditTrace _mapAuditTrace(Map<String, dynamic> m) {
    final ir = m['ingestorResult'] as Map<String, dynamic>? ?? {};
    final checks = (m['complianceChecks'] as List<dynamic>?)
            ?.map((c) => ComplianceCheck(
                  label: c['label'] as String? ?? '',
                  detail: c['detail'] as String? ?? '',
                  passed: c['passed'] as bool? ?? false,
                ))
            .toList() ??
        [];
    final steps = (m['reasoningLog'] as List<dynamic>?)
            ?.map((s) => AgentTraceStep(
                  lineNumber: s['lineNumber'] as int? ?? 0,
                  agent: s['agent'] as String? ?? 'System',
                  content: s['content'] as String? ?? '',
                  isCritical: s['isCritical'] as bool? ?? false,
                ))
            .toList() ??
        [];

    return AuditTrace(
      ingestorResult: IngestorExtraction(
        intent: ir['intent'] as String? ?? '',
        damageType: ir['damageType'] as String? ?? '',
        sentiment: ir['sentiment'] as String? ?? 'Neutral',
        confidence: (ir['confidence'] as num?)?.toDouble() ?? 0.0,
      ),
      investigatorConfidence:
          (m['investigatorConfidence'] as num?)?.toDouble() ?? 0.0,
      investigatorSummary: m['investigatorSummary'] as String? ?? '',
      complianceChecks: checks,
      verdict: m['verdict'] as String? ?? 'Pending',
      reasoningLog: steps,
    );
  }

  // ── GET /api/merchants/policies ──

  @override
  Future<List<MerchantPolicy>> getMerchantPolicies() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/merchants/policies'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Get policies failed: ${response.statusCode}');
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => _mapPolicy(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MerchantPolicy> getMerchantPolicy(String merchantId) async {
    final policies = await getMerchantPolicies();
    return policies.firstWhere(
      (p) => p.merchantId == merchantId,
      orElse: () => policies.first,
    );
  }

  MerchantPolicy _mapPolicy(Map<String, dynamic> m) {
    return MerchantPolicy(
      merchantId: m['merchantId'] as String? ?? '',
      merchantName: m['merchantName'] as String? ?? '',
      region: m['region'] as String? ?? 'MY',
      autoRefundThreshold:
          (m['autoRefundThreshold'] as num?)?.toDouble() ?? 50.0,
      certaintyCutoff:
          (m['certaintyCutoff'] as num?)?.toDouble() ?? 85.0,
      maxAutoAmount: (m['maxAutoAmount'] as num?)?.toDouble() ?? 200.0,
      categories: (m['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isActive: m['isActive'] as bool? ?? true,
      policyVersion: m['policyVersion'] as String? ?? 'v1.0',
    );
  }

  // ── PUT /api/merchants/{id}/policy ── (not yet in backend — no-op for now)

  @override
  Future<MerchantPolicy> updateMerchantPolicy(MerchantPolicy policy) async {
    // Backend doesn't have PUT endpoint yet — return unchanged
    return policy;
  }
}
