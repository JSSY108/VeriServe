import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TraceDashboardScreen extends StatefulWidget {
  const TraceDashboardScreen({super.key});

  @override
  State<TraceDashboardScreen> createState() => _TraceDashboardScreenState();
}

class _TraceDashboardScreenState extends State<TraceDashboardScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = false;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final logs = await ApiService.fetchAuditLogs();
      setState(() => _logs = logs);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('God Mode — Trace Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No audit logs yet'))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text(log['action'] ?? ''),
                        subtitle: Text(
                          log['raw_json'] != null
                              ? const JsonEncoder.withIndent('  ').convert(log['raw_json'])
                              : '',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                        trailing: Text(
                          log['timestamp'] ?? '',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
