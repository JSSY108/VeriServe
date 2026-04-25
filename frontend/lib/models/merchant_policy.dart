/// Merchant policy configuration — drives the Auditor Agent's decisions.
class MerchantPolicy {
  final String merchantId;
  final String merchantName;
  final String region;
  final double autoRefundThreshold; // Max auto-approve amount (RM)
  final double certaintyCutoff;     // Min confidence % for auto-approval
  final double maxAutoAmount;       // Hard cap for automated payouts
  final List<String> categories;
  final bool isActive;
  final String policyVersion;

  const MerchantPolicy({
    required this.merchantId,
    required this.merchantName,
    this.region = 'MY',
    this.autoRefundThreshold = 50.0,
    this.certaintyCutoff = 95.0,
    this.maxAutoAmount = 200.0,
    this.categories = const ['Electronics', 'Apparel', 'Perishables'],
    this.isActive = true,
    this.policyVersion = 'v4.2-Secure',
  });

  MerchantPolicy copyWith({
    double? autoRefundThreshold,
    double? certaintyCutoff,
    double? maxAutoAmount,
    List<String>? categories,
    bool? isActive,
  }) {
    return MerchantPolicy(
      merchantId: merchantId,
      merchantName: merchantName,
      region: region,
      autoRefundThreshold: autoRefundThreshold ?? this.autoRefundThreshold,
      certaintyCutoff: certaintyCutoff ?? this.certaintyCutoff,
      maxAutoAmount: maxAutoAmount ?? this.maxAutoAmount,
      categories: categories ?? this.categories,
      isActive: isActive ?? this.isActive,
      policyVersion: policyVersion,
    );
  }
}
