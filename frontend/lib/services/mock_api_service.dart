import '../models/claim.dart';
import '../models/merchant_policy.dart';
import 'api_service.dart';

/// Mock implementation of [ApiService] with pre-populated data
/// matching the Stitch screen content for demo purposes.
class MockApiService implements ApiService {
  // ── Pre-populated Claims ──
  final List<Claim> _mockClaims = [
    Claim(
      id: 'CLM-001',
      orderId: 'SHP-992',
      merchant: 'Shopee',
      category: 'Electronics',
      description:
          'yo my shopee package SHP-992 is totally rekt, the screen is cracked and i want my money back ASAP!!',
      evidenceUrls: [
        'https://lh3.googleusercontent.com/aida-public/AB6AXuAr7o5Re7eI0LYRCn4fi0WQ8Dyl1M5_BI9U-lQIVJP-fEwc9SgX_kLBhkQx1arQAFjCh8eFqALKYIWj82dnroIADl1gJ9Ic-8lhgcsnGavw-L_HX0OtlHb5enX3S9hU8qbDRC1cjtmFJHtVXpoxnTfi4nZmXzGwheYav3R_XhbxJUjKWMSgwsuc8spcWfWsL5TzNSu0s1h1UzHq_Wq6Xvtvs_zxOCDVg5sfGCny_dAjcWaBH2Bi-qecOO3dLdS6Fh21LXRPJooAEXA',
      ],
      status: ClaimStatus.resolved,
      riskLevel: RiskLevel.low,
      confidence: 98.42,
      claimAmount: 42.0,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      resolvedAt: DateTime.now().subtract(const Duration(hours: 1)),
      auditTrace: _buildShopeeTrace(),
    ),
    Claim(
      id: 'CLM-002',
      orderId: 'GF-994',
      merchant: 'GrabFood',
      category: 'Perishables',
      description: 'Food arrived cold and soggy, packaging was torn open',
      evidenceUrls: [],
      status: ClaimStatus.investigating,
      riskLevel: RiskLevel.medium,
      confidence: null,
      claimAmount: 28.50,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    Claim(
      id: 'CLM-003',
      orderId: 'ZAL-883',
      merchant: 'Zalora',
      category: 'Apparel',
      description: 'Received wrong size and color, tag says L but fits like XS',
      evidenceUrls: [],
      status: ClaimStatus.resolved,
      riskLevel: RiskLevel.high,
      confidence: 72.1,
      claimAmount: 189.00,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      resolvedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  // ── Pre-populated Policies ──
  final List<MerchantPolicy> _mockPolicies = [
    const MerchantPolicy(
      merchantId: 'SHOPEE_ID_882',
      merchantName: 'Shopee',
      region: 'MY',
      autoRefundThreshold: 50.0,
      certaintyCutoff: 95.0,
      maxAutoAmount: 200.0,
      categories: ['Electronics', 'Home & Living', 'Fashion'],
      isActive: true,
      policyVersion: 'v4.2-Secure',
    ),
    const MerchantPolicy(
      merchantId: 'GF_ID_401',
      merchantName: 'GrabFood',
      region: 'MY',
      autoRefundThreshold: 30.0,
      certaintyCutoff: 90.0,
      maxAutoAmount: 100.0,
      categories: ['Perishables', 'Beverages'],
      isActive: true,
      policyVersion: 'v3.1-Fresh',
    ),
    const MerchantPolicy(
      merchantId: 'ZAL_ID_220',
      merchantName: 'Zalora',
      region: 'MY',
      autoRefundThreshold: 80.0,
      certaintyCutoff: 92.0,
      maxAutoAmount: 500.0,
      categories: ['Apparel', 'Footwear', 'Accessories'],
      isActive: true,
      policyVersion: 'v2.8-Luxe',
    ),
  ];

  @override
  Future<List<Claim>> getClaims({String? merchantFilter}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (merchantFilter != null) {
      return _mockClaims
          .where((c) => c.merchant == merchantFilter)
          .toList();
    }
    return List.from(_mockClaims);
  }

  @override
  Future<Claim> submitClaim(Claim claim) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mockClaims.insert(0, claim);
    return claim;
  }

  @override
  Future<AuditTrace> getAuditTrace(String claimId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _buildShopeeTrace();
  }

  @override
  Future<List<MerchantPolicy>> getMerchantPolicies() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.from(_mockPolicies);
  }

  @override
  Future<MerchantPolicy> getMerchantPolicy(String merchantId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _mockPolicies.firstWhere(
      (p) => p.merchantId == merchantId,
      orElse: () => _mockPolicies.first,
    );
  }

  @override
  Future<MerchantPolicy> updateMerchantPolicy(MerchantPolicy policy) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final idx =
        _mockPolicies.indexWhere((p) => p.merchantId == policy.merchantId);
    if (idx >= 0) {
      _mockPolicies[idx] = policy;
    }
    return policy;
  }

  /// Build the full reasoning trace for the Shopee SHP-992 demo claim.
  static AuditTrace _buildShopeeTrace() {
    return const AuditTrace(
      ingestorResult: IngestorExtraction(
        intent: 'Refund',
        damageType: 'Impact/Cracked Screen',
        sentiment: 'Urgent / Negative',
        confidence: 97.8,
      ),
      investigatorConfidence: 98.42,
      investigatorSummary:
          'Critical damage detected on LCD panel. Fracture pattern consistent with blunt force post-boxing.',
      complianceChecks: [
        ComplianceCheck(
          label: 'Claim Value Validation',
          detail: 'RM 42.00 is below the RM 50.00 automated limit.',
          passed: true,
        ),
        ComplianceCheck(
          label: 'Evidence Strength Analysis',
          detail: '98.4% visual match exceeds the 95% certainty threshold.',
          passed: true,
        ),
        ComplianceCheck(
          label: 'Merchant Status Verification',
          detail: 'Merchant account is active and in good standing.',
          passed: true,
        ),
      ],
      verdict: 'Autonomous Approval',
      reasoningLog: [
        AgentTraceStep(
            lineNumber: 1,
            agent: 'System',
            content: '> Initializing context block...'),
        AgentTraceStep(
            lineNumber: 2,
            agent: 'System',
            content: '> Loading Merchant Profile: [SHOPEE_ID_882]'),
        AgentTraceStep(
            lineNumber: 3,
            agent: 'Ingestor',
            content: '> Category Matrix: [ELECTRONICS] -> Fragility Index: 0.85'),
        AgentTraceStep(
            lineNumber: 4,
            agent: 'Investigator',
            content:
                ' [Vision] Analyzing pixel delta between PoD and Customer Upload...',
            isCritical: false),
        AgentTraceStep(
            lineNumber: 5,
            agent: 'Investigator',
            content:
                '> Structural integrity scan on bounding box: Box appears intact at PoD.'),
        AgentTraceStep(
            lineNumber: 6,
            agent: 'Investigator',
            content: '> Internal geometry extraction...'),
        AgentTraceStep(
            lineNumber: 7,
            agent: 'Investigator',
            content:
                ' [GLM] Critical damage detected on LCD panel. Risk: High.',
            isCritical: true),
        AgentTraceStep(
            lineNumber: 8,
            agent: 'Investigator',
            content:
                '> Fracture pattern consistent with blunt force post-boxing.'),
        AgentTraceStep(
            lineNumber: 9,
            agent: 'Auditor',
            content: '> Synthesizing final confidence score...'),
        AgentTraceStep(
            lineNumber: 10,
            agent: 'Auditor',
            content: '> RESULT: Claim Valid. Confidence 98.42%'),
      ],
    );
  }
}
