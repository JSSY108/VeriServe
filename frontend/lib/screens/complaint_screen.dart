import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _orderIdController = TextEditingController();
  final _claimController = TextEditingController();
  final _imageUrlController = TextEditingController();
  bool _loading = false;
  String? _result;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final response = await ApiService.orchestrate(
        orderId: int.parse(_orderIdController.text),
        customerClaim: _claimController.text,
        customerImageUrl: _imageUrlController.text,
      );
      setState(() => _result = 'Ticket #${response['ticket_id']}\n'
          'Status: ${response['ticket_status']}\n'
          'Vision Score: ${response['vision_match_score']}');
    } catch (e) {
      setState(() => _result = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Complaint')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _orderIdController,
              decoration: const InputDecoration(labelText: 'Order ID'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _claimController,
              decoration: const InputDecoration(labelText: 'Describe your complaint'),
              maxLines: 3,
            ),
            TextField(
              controller: _imageUrlController,
              decoration: const InputDecoration(labelText: 'Image URL'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit'),
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              Text(_result!, style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}
