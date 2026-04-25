import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/claim.dart';
import '../../state/app_state.dart';
import '../../theme/veriserve_colors.dart';

/// Phase 1: Claim Input Screen — Order lookup, description, evidence upload.
class ClaimInputScreen extends StatefulWidget {
  const ClaimInputScreen({super.key});

  @override
  State<ClaimInputScreen> createState() => _ClaimInputScreenState();
}

class _ClaimInputScreenState extends State<ClaimInputScreen> {
  final _orderCtrl = TextEditingController(text: '1');
  final _descCtrl = TextEditingController(
      text: 'The food arrived completely smashed and spilled everywhere');
  final _imageUrlCtrl = TextEditingController();
  String _detectedMerchant = 'Grab';
  String? _selectedCategory;

  static const _categories = ['Food', 'Electronics', 'Apparel'];

  @override
  void initState() {
    super.initState();
    _orderCtrl.addListener(_onOrderChanged);
    _onOrderChanged();
  }

  void _onOrderChanged() {
    final merchant = Claim.merchantFromOrderId(_orderCtrl.text);
    final scenario = AppState().getScenario(_orderCtrl.text.trim());
    setState(() {
      _detectedMerchant = merchant;
      if (scenario != null) {
        _selectedCategory = scenario.category;
        _descCtrl.text = scenario.description;
        _imageUrlCtrl.text = scenario.customerImageUrl;
      } else {
        _selectedCategory = _inferCategory(merchant);
      }
    });
  }

  String? _inferCategory(String merchant) {
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
        return null;
    }
  }

  @override
  void dispose() {
    _orderCtrl.dispose();
    _descCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VeriServeColors.background,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
          decoration: const BoxDecoration(
            color: VeriServeColors.surface,
            border: Border(
                bottom:
                    BorderSide(color: VeriServeColors.surfaceContainerHighest)),
          ),
          child: Column(children: [
            Text('Partner Resolution Portal',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: VeriServeColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified, size: 14, color: VeriServeColors.deepNavy),
                SizedBox(width: 4),
                Text('POWERED BY VERISERVE',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: VeriServeColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Order Lookup
              const Text('ORDER LOOKUP',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: VeriServeColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextField(
                controller: _orderCtrl,
                decoration: InputDecoration(
                  hintText: 'Enter Order ID (1-4 for demo scenarios)',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                            color: VeriServeColors.primaryContainer,
                            borderRadius: BorderRadius.circular(4)),
                        child: Center(
                            child: Text(
                                _detectedMerchant.substring(0, 2).toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)))),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Description
              const Text('ISSUE DESCRIPTION',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: VeriServeColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'E.g., The box arrived completely crushed...',
                ),
              ),
              const SizedBox(height: 8),

              // AI categorization badge
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      VeriServeColors.secondaryFixedDim.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: VeriServeColors.secondaryFixedDim
                          .withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.auto_awesome,
                      size: 18, color: VeriServeColors.deepNavy),
                  const SizedBox(width: 8),
                  Expanded(
                      child: RichText(
                          text: TextSpan(
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 18 / 13,
                        color: VeriServeColors.onSurfaceVariant),
                    children: [
                      const TextSpan(text: 'VeriServe AI categorizing as: '),
                      TextSpan(
                          text: '${_selectedCategory ?? "General"} / Physical Damage',
                          style: const TextStyle(
                              color: VeriServeColors.deepNavy,
                              fontWeight: FontWeight.w600)),
                    ],
                  ))),
                ]),
              ),
              const SizedBox(height: 20),

              // Category Selector
              const Text('CATEGORY',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: VeriServeColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  hintText: 'Select category',
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              const SizedBox(height: 20),

              // Evidence Upload
              const Text('EVIDENCE IMAGE URL',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: VeriServeColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextField(
                controller: _imageUrlCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. smashed_food.jpg or full URL',
                  prefixIcon: Icon(Icons.image, color: VeriServeColors.onSurfaceVariant),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              // Image preview
              if (_imageUrlCtrl.text.isNotEmpty)
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: VeriServeColors.outlineVariant),
                    color: VeriServeColors.surfaceContainer,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _imageUrlCtrl.text.startsWith('http')
                      ? Image.network(
                          _imageUrlCtrl.text,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image, size: 36, color: VeriServeColors.outline),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.image, size: 36, color: VeriServeColors.outline),
                              const SizedBox(height: 4),
                              Text(_imageUrlCtrl.text, style: const TextStyle(fontSize: 12, color: VeriServeColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<AppState>().submitClaim(
                            orderId: _orderCtrl.text,
                            userCategorySelection: _selectedCategory,
                            description: _descCtrl.text,
                            imageUrl: _imageUrlCtrl.text,
                          );
                    },
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Submit Claim for Verification',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  )),

              const SizedBox(height: 24),
              const Divider(color: VeriServeColors.surfaceContainerHighest),
              const SizedBox(height: 24),

              // Recent Resolutions
              Text('Recent Resolutions',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              _recentCard('Claim #GF-994', '10m ago',
                  'Verifying with Rider Data...', Icons.sync, true),
              const SizedBox(height: 8),
              _recentCard('Claim #ZAL-883', '2h ago', 'Refund Approved.',
                  Icons.check_circle, false),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _recentCard(String title, String time, String status, IconData icon,
      bool isAnimated) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: VeriServeColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VeriServeColors.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text(time.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: VeriServeColors.onSurfaceVariant)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(icon,
              size: 18,
              color: isAnimated
                  ? VeriServeColors.secondary
                  : const Color(0xFF059669)),
          const SizedBox(width: 4),
          Text(status,
              style: TextStyle(
                  fontSize: 14,
                  color: isAnimated
                      ? VeriServeColors.secondary
                      : const Color(0xFF059669),
                  fontWeight: isAnimated ? FontWeight.w400 : FontWeight.w500)),
        ]),
      ]),
    );
  }
}
