/// Status of a claim in the audit pipeline.
enum ClaimStatus {
  submitted,
  ingesting,
  investigating,
  auditing,
  resolved,
  denied,
  escalated,
}

/// Risk classification for a claim.
enum RiskLevel { low, medium, high }

/// A single reasoning step from an AI agent.
class AgentTraceStep {
  final int lineNumber;
  final String agent; // 'Ingestor', 'Investigator', 'Auditor'
  final String content;
  final bool isCritical;

  const AgentTraceStep({
    required this.lineNumber,
    required this.agent,
    required this.content,
    this.isCritical = false,
  });
}

/// NLP extractions from the Ingestor Agent.
class IngestorExtraction {
  final String intent;
  final String damageType;
  final String sentiment;
  final double confidence;

  const IngestorExtraction({
    required this.intent,
    required this.damageType,
    required this.sentiment,
    required this.confidence,
  });
}

/// The complete audit trace for a claim.
class AuditTrace {
  final IngestorExtraction ingestorResult;
  final double investigatorConfidence;
  final String investigatorSummary;
  final List<ComplianceCheck> complianceChecks;
  final String verdict;
  final List<AgentTraceStep> reasoningLog;

  const AuditTrace({
    required this.ingestorResult,
    required this.investigatorConfidence,
    required this.investigatorSummary,
    required this.complianceChecks,
    required this.verdict,
    required this.reasoningLog,
  });
}

/// A single compliance check from the Auditor Agent.
class ComplianceCheck {
  final String label;
  final String detail;
  final bool passed;

  const ComplianceCheck({
    required this.label,
    required this.detail,
    required this.passed,
  });
}

/// Core claim model.
class Claim {
  final String id;
  final String orderId;
  final String merchant; // 'Shopee', 'GrabFood', 'Zalora'
  final String category;
  final String description;
  final List<String> evidenceUrls;
  final ClaimStatus status;
  final RiskLevel riskLevel;
  final double? confidence;
  final AuditTrace? auditTrace;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final double? claimAmount;
  final String? userCategorySelection;
  final bool humanVerified;
  final String? riderPodUrl;

  const Claim({
    required this.id,
    required this.orderId,
    required this.merchant,
    required this.category,
    required this.description,
    this.evidenceUrls = const [],
    this.status = ClaimStatus.submitted,
    this.riskLevel = RiskLevel.low,
    this.confidence,
    this.auditTrace,
    required this.createdAt,
    this.resolvedAt,
    this.claimAmount,
    this.userCategorySelection,
    this.humanVerified = false,
    this.riderPodUrl,
  });

  Claim copyWith({
    ClaimStatus? status,
    double? confidence,
    RiskLevel? riskLevel,
    AuditTrace? auditTrace,
    DateTime? resolvedAt,
    bool? humanVerified,
    String? riderPodUrl,
  }) {
    return Claim(
      id: id,
      orderId: orderId,
      merchant: merchant,
      category: category,
      description: description,
      evidenceUrls: evidenceUrls,
      status: status ?? this.status,
      riskLevel: riskLevel ?? this.riskLevel,
      confidence: confidence ?? this.confidence,
      auditTrace: auditTrace ?? this.auditTrace,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      claimAmount: claimAmount,
      userCategorySelection: userCategorySelection,
      humanVerified: humanVerified ?? this.humanVerified,
      riderPodUrl: riderPodUrl ?? this.riderPodUrl,
    );
  }

  /// Detect merchant from order ID prefix or numeric mapping.
  static String merchantFromOrderId(String orderId) {
    final upper = orderId.toUpperCase();
    if (upper.startsWith('SHP')) return 'Shopee';
    if (upper.startsWith('GF') || upper.startsWith('GRAB')) return 'GrabFood';
    if (upper.startsWith('ZAL')) return 'Zalora';
    if (upper.startsWith('DHL')) return 'DHL';
    // Numeric mapping: 1=Grab, 2=Zalora, 3=DHL, 4=Shopee
    final numPart = orderId.replaceAll(RegExp(r'[^0-9]'), '');
    if (numPart == '1') return 'Grab';
    if (numPart == '2') return 'Zalora';
    if (numPart == '3') return 'DHL';
    if (numPart == '4') return 'Shopee';
    return 'Unknown';
  }
}
