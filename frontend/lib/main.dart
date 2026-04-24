import 'package:flutter/material.dart';
import 'screens/complaint_screen.dart';
import 'screens/trace_dashboard_screen.dart';

void main() {
  runApp(const VeriServeApp());
}

class VeriServeApp extends StatelessWidget {
  const VeriServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VeriServe',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VeriServe')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ComplaintScreen()),
              ),
              child: const Text('Submit Complaint'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TraceDashboardScreen()),
              ),
              child: const Text('God Mode — Trace Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
