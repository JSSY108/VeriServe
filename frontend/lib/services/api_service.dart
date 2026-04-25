import '../models/claim.dart';
import '../models/merchant_policy.dart';

/// Abstract service layer for VeriServe API calls.
/// Swap [MockApiService] for [LiveApiService] to connect to the FastAPI backend.
abstract class ApiService {
  /// Submit a new claim and receive the processing result.
  Future<Claim> submitClaim(Claim claim);

  /// Get all claims, optionally filtered by merchant.
  Future<List<Claim>> getClaims({String? merchantFilter});

  /// Get the full audit trace for a specific claim.
  Future<AuditTrace> getAuditTrace(String claimId);

  /// Get all merchant policies.
  Future<List<MerchantPolicy>> getMerchantPolicies();

  /// Get a specific merchant policy.
  Future<MerchantPolicy> getMerchantPolicy(String merchantId);

  /// Update a merchant policy.
  Future<MerchantPolicy> updateMerchantPolicy(MerchantPolicy policy);
}
