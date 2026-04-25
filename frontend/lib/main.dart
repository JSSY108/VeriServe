import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'theme/veriserve_theme.dart';
import 'screens/shell_screen.dart';

void main() {
  runApp(const VeriServeApp());
}

class VeriServeApp extends StatelessWidget {
  const VeriServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'VeriServe — Veracity-as-a-Service',
        debugShowCheckedModeBanner: false,
        theme: VeriServeTheme.light,
        home: const ShellScreen(),
      ),
    );
  }
}
