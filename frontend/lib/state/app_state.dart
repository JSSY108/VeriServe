import 'package:flutter/material.dart';
import '../models/claim.dart';
import '../models/merchant_policy.dart';
import '../services/live_api_service.dart';
import '../services/api_service.dart';

/// Scenario config for the 4-preset demo order IDs.
class ScenarioConfig {
  final String customerImageUrl;
  final String category;
  final String description;
  const ScenarioConfig({
    required this.customerImageUrl,
    required this.category,
    required this.description,
  });
}

/// Global application state — controls the dual-persona mode, claims lifecycle,
/// and real-time sync between Admin and Customer views.
class AppState extends ChangeNotifier {
  // ── Demo Scenario Matrix ──
  static const scenarioMatrix = {
    '1': ScenarioConfig(
      customerImageUrl: 'https://placehold.co/600x400/F44336/white?text=Smashed+Pizza+Box',
      category: 'Food',
      description: 'The food arrived completely smashed and spilled everywhere',
    ),
    '2': ScenarioConfig(
      customerImageUrl: 'https://placehold.co/600x400/F44336/white?text=Broken+iPhone+Screen',
      category: 'Electronics',
      description: 'My phone screen is cracked — I ordered electronics not food!',
    ),
    '3': ScenarioConfig(
      customerImageUrl: 'https://placehold.co/600x400/FF9800/white?text=Dented+Can+Same+As+PoD',
      category: 'Apparel',
      description: 'The item arrived dented but it looks like it was already damaged before shipping',
    ),
    '4': ScenarioConfig(
      customerImageUrl: 'https://placehold.co/600x400/FFC107/white?text=Minor+Scratch',
      category: 'Electronics',
      description: 'There is a small scratch on the package, not sure if the item is affected',
    ),
  };

  ScenarioConfig? getScenario(String orderId) => scenarioMatrix[orderId];

  // ── Mode Toggle ──
  bool _isAdminMode = true;
  bool get isAdminMode => _isAdminMode;

  void toggleMode() {
    _isAdminMode = !_isAdminMode;
    notifyListeners();
  }

  void setAdminMode(bool value) {
    _isAdminMode = value;
    notifyListeners();
  }

  // ── Admin Navigation ──
  int _adminTabIndex = 0;
  int get adminTabIndex => _adminTabIndex;

  void setAdminTab(int index) {
    _adminTabIndex = index;
    notifyListeners();
  }

  // ── Merchant Filter (for deep-link from Dashboard → Claims Queue) ──
  String? _activeMerchantFilter;
  String? get activeMerchantFilter => _activeMerchantFilter;

  void setActiveMerchantFilter(String? merchant) {
    _activeMerchantFilter = merchant;
    notifyListeners();
  }

  void clearMerchantFilter() {
    _activeMerchantFilter = null;
    notifyListeners();
  }

  // ── Customer Flow Step ──
  int _customerStep = 0; // 0=Input, 1=Processing, 2=Result
  int get customerStep => _customerStep;

  void setCustomerStep(int step) {
    _customerStep = step;
    notifyListeners();
  }

  // ── Claims Store ──
  List<Claim> _claims = [];
  List<Claim> get claims => List.unmodifiable(_claims);

  String? _activeClaimId;
  String? get activeClaimId => _activeClaimId;

  Claim? get activeClaim {
    if (_activeClaimId == null) return null;
    try {
      return _claims.firstWhere((c) => c.id == _activeClaimId);
    } catch (_) {
      return null;
    }
  }

  void setActiveClaim(String? id) {
    _activeClaimId = id;
    notifyListeners();
  }

  // ── Merchant Policies ──
  Map<String, MerchantPolicy> _policies = {};
  Map<String, MerchantPolicy> get policies => Map.unmodifiable(_policies);

  MerchantPolicy? getPolicy(String merchantId) => _policies[merchantId];

  void updatePolicy(MerchantPolicy policy) {
    _policies[policy.merchantId] = policy;
    _apiService.updateMerchantPolicy(policy);
    notifyListeners();
  }

  // ── API Service (swappable) ──
  late ApiService _apiService;
  ApiService get apiService => _apiService;

  // ── Init ──
  AppState() {
    _apiService = LiveApiService();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      _claims = await _apiService.getClaims();
      _policies = {
        for (final p in await _apiService.getMerchantPolicies()) p.merchantId: p,
      };
    } catch (_) {
      // If backend is down, start empty
      _claims = [];
      _policies = {};
    }
    notifyListeners();
  }

  /// Reload claims from backend (called after tab switches, etc.)
  Future<void> refreshClaims() async {
    try {
      _claims = await _apiService.getClaims();
    } catch (_) {}
    notifyListeners();
  }

  /// Submit a new claim from the Customer Portal.
  /// Calls the real backend orchestration endpoint.
  Future<void> submitClaim({
    required String orderId,
    String? userCategorySelection,
    required String description,
    String? imageUrl,
  }) async {
    final merchant = Claim.merchantFromOrderId(orderId);
    final category = userCategorySelection ?? _inferCategory(merchant);

    final newClaim = Claim(
      id: 'CLM-${DateTime.now().millisecondsSinceEpoch}',
      orderId: orderId,
      merchant: merchant,
      category: category,
      description: description,
      evidenceUrls: imageUrl != null && imageUrl.isNotEmpty ? [imageUrl] : [],
      status: ClaimStatus.submitted,
      riskLevel: RiskLevel.medium,
      createdAt: DateTime.now(),
      userCategorySelection: userCategorySelection,
    );

    _claims.insert(0, newClaim);
    _activeClaimId = newClaim.id;
    _customerStep = 1; // Move to processing
    notifyListeners();

    // Animate through pipeline phases while waiting for backend
    _animatePipeline(newClaim.id);

    // Call real backend
    try {
      final result = await _apiService.submitClaim(newClaim);

      // Replace the placeholder claim with the real result
      final idx = _claims.indexWhere((c) => c.id == newClaim.id);
      if (idx >= 0) {
        _claims[idx] = result;
        _activeClaimId = result.id;
      } else {
        _claims.insert(0, result);
        _activeClaimId = result.id;
      }
    } catch (_) {
      // On failure, mark as escalated
      final idx = _claims.indexWhere((c) => c.id == newClaim.id);
      if (idx >= 0) {
        _claims[idx] = _claims[idx].copyWith(
          status: ClaimStatus.escalated,
          resolvedAt: DateTime.now(),
        );
      }
    }

    _customerStep = 2; // Move to result
    notifyListeners();
  }

  /// Animate the 3-agent pipeline UI while the backend processes.
  void _animatePipeline(String claimId) async {
    _updateClaimStatus(claimId, ClaimStatus.ingesting);
    await Future.delayed(const Duration(seconds: 2));
    _updateClaimStatus(claimId, ClaimStatus.investigating);
    await Future.delayed(const Duration(seconds: 2));
    _updateClaimStatus(claimId, ClaimStatus.auditing);
  }

  /// Approve a claim from Admin Mode (Tier 3 Deep Dive).
  void approveClaim(String claimId) {
    final idx = _claims.indexWhere((c) => c.id == claimId);
    if (idx >= 0) {
      final claim = _claims[idx];
      // Add Payment API step to the audit trace
      AuditTrace? updatedTrace = claim.auditTrace;
      if (updatedTrace != null) {
        final steps = List<AgentTraceStep>.from(updatedTrace.reasoningLog);
        steps.add(AgentTraceStep(
          lineNumber: steps.length + 1,
          agent: 'Admin',
          content: '> Payment API executed — refund disbursed by human review',
          isCritical: false,
        ));
        updatedTrace = AuditTrace(
          ingestorResult: updatedTrace.ingestorResult,
          investigatorConfidence: updatedTrace.investigatorConfidence,
          investigatorSummary: updatedTrace.investigatorSummary,
          complianceChecks: updatedTrace.complianceChecks,
          verdict: updatedTrace.verdict,
          reasoningLog: steps,
        );
      }
      _claims[idx] = claim.copyWith(
        status: ClaimStatus.resolved,
        resolvedAt: DateTime.now(),
        humanVerified: true,
        auditTrace: updatedTrace,
      );
      notifyListeners();
    }
  }

  /// Deny a claim from Admin Mode.
  void denyClaim(String claimId) {
    final idx = _claims.indexWhere((c) => c.id == claimId);
    if (idx >= 0) {
      _claims[idx] = _claims[idx].copyWith(
        status: ClaimStatus.denied,
        resolvedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Reset customer flow to input step (for demo replayability).
  void resetCustomerFlow() {
    _customerStep = 0;
    _activeClaimId = null;
    notifyListeners();
  }

  void _updateClaimStatus(String claimId, ClaimStatus status) {
    final idx = _claims.indexWhere((c) => c.id == claimId);
    if (idx >= 0) {
      _claims[idx] = _claims[idx].copyWith(status: status);
      notifyListeners();
    }
  }

  String _inferCategory(String merchant) {
    switch (merchant) {
      case 'Shopee':
        return 'Electronics';
      case 'GrabFood':
      case 'Grab':
        return 'Food';
      case 'Zalora':
        return 'Electronics';
      case 'DHL':
        return 'Apparel';
      default:
        return 'General';
    }
  }
}
