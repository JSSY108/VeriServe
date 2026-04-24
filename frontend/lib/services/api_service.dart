import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  static Future<Map<String, dynamic>> orchestrate({
    required int orderId,
    required String customerClaim,
    required String customerImageUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/orchestrate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'order_id': orderId,
        'customer_claim': customerClaim,
        'customer_image_url': customerImageUrl,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> fetchAuditLogs() async {
    final response = await http.get(Uri.parse('$baseUrl/api/audit-logs'));
    final List body = jsonDecode(response.body);
    return body.cast<Map<String, dynamic>>();
  }
}
