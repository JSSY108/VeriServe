import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/claim.dart';
import '../theme/veriserve_colors.dart';

/// Terminal-style reasoning trace for Ilmu-GLM-5.1 output.
/// Upgraded: Deep-black bg, syntax highlighting, hover interactivity, live cursor.
class ReasoningTrace extends StatelessWidget {
  final List<AgentTraceStep> steps;
  final VoidCallback? onApprove;
  final VoidCallback? onFlag;

  const ReasoningTrace(
      {super.key, required this.steps, this.onApprove, this.onFlag});

  String _buildCopyText() {
    final buf = StringBuffer();
    buf.writeln('ILMU-GLM-5.1 REASONING TRACE');
    buf.writeln('═' * 50);
    for (final step in steps) {
      buf.writeln('[${step.agent}] ${step.content}');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A58A6FF),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Color(0x0858A6FF),
            blurRadius: 48,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          const Icon(Icons.memory, size: 16, color: Color(0xFF58A6FF)),
          const SizedBox(width: 8),
          const Text(
            'ILMU-GLM-5.1 REASONING TRACE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: Color(0xFF8B949E),
            ),
          ),
          const Spacer(),
          // Live indicator
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF3FB950),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF3FB950),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: Color(0xFF8B949E)),
            tooltip: 'Copy trace to clipboard',
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: _buildCopyText())),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 8),
          // macOS-style window dots
          Row(
            children: [
              _dot(const Color(0xFFFF5F56)),
              _dot(const Color(0xFFFFBD2E)),
              _dot(const Color(0xFF27C93F)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _buildBody() {
    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final step in steps) _InteractiveTraceLine(step: step),
            Row(children: [
              Text(
                (steps.length + 1).toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF484F58),
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              _BlinkingCursor(),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: onFlag,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B949E),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
            child: const Text('Flag for Review'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('Approve Claim'),
          ),
        ],
      ),
    );
  }
}

// ─── Interactive Trace Line ────────────────────────────────────────────────────

class _InteractiveTraceLine extends StatefulWidget {
  final AgentTraceStep step;
  const _InteractiveTraceLine({required this.step});

  @override
  State<_InteractiveTraceLine> createState() => _InteractiveTraceLineState();
}

class _InteractiveTraceLineState extends State<_InteractiveTraceLine> {
  bool _hovered = false;

  Color get _agentColor {
    switch (widget.step.agent) {
      case 'Ingestor':
        return const Color(0xFF58A6FF);
      case 'Investigator':
        return const Color(0xFFD2A8FF);
      case 'Auditor':
        return const Color(0xFF3FB950);
      case 'Admin':
        return const Color(0xFFFFA657);
      default:
        return const Color(0xFF8B949E);
    }
  }

  IconData get _agentIcon {
    switch (widget.step.agent) {
      case 'Ingestor':
        return Icons.data_exploration;
      case 'Investigator':
        return Icons.visibility;
      case 'Auditor':
        return Icons.gavel;
      case 'Admin':
        return Icons.person;
      default:
        return Icons.smart_toy;
    }
  }

  /// Parse key: value pairs into syntax-colored TextSpans.
  List<TextSpan> _parseContent(String content) {
    final spans = <TextSpan>[];
    // Match: key: | "quoted" | numbers/% | words | punctuation/spaces
    final regex = RegExp(
        r'(\w[\w_]*\s*:)|(".*?")|([\d]+\.?[\d]*%?)|([^\s:,\[\]{}"]+)|([\s:,\[\]{}]+)');
    for (final match in regex.allMatches(content)) {
      final text = match.group(0)!;
      Color color;
      FontWeight weight = FontWeight.w400;
      if (match.group(1) != null) {
        color = const Color(0xFF58A6FF); // key:
        weight = FontWeight.w600;
      } else if (match.group(2) != null) {
        color = const Color(0xFFA5D6FF); // "string"
      } else if (match.group(3) != null) {
        color = const Color(0xFF79C0FF); // number
      } else if (match.group(4) != null) {
        color = const Color(0xFF7EE787); // value word
      } else {
        color = const Color(0xFF8B949E); // punctuation/space
      }
      spans.add(TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontWeight: weight,
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.5,
        ),
      ));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isCrit = widget.step.isCritical;
    final agentColor = _agentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.text,
      child: Tooltip(
        message: 'Source: Ilmu-GLM-5.1 · Agent: ${widget.step.agent}',
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        textStyle:
            const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(
            vertical: _hovered ? 12 : 8,
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: isCrit
                ? const Color(0x14FF5F56)
                : _hovered
                    ? const Color(0x0DFFFFFF)
                    : const Color(0x06FFFFFF),
            borderRadius: BorderRadius.circular(6),
            border: isCrit
                ? const Border(
                    left: BorderSide(color: Color(0xFFFF5F56), width: 3))
                : Border(
                    left: BorderSide(
                        color: agentColor.withValues(alpha: 0.5), width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_agentIcon, size: 12, color: agentColor),
                  const SizedBox(width: 6),
                  Text(
                    widget.step.agent.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: agentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'L${widget.step.lineNumber.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF484F58),
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (_hovered) ...[
                    const Spacer(),
                    _HoverAction(
                      icon: Icons.copy,
                      label: 'Copy JSON',
                      onTap: () => Clipboard.setData(ClipboardData(
                        text:
                            '{"agent":"${widget.step.agent}","line":${widget.step.lineNumber},"content":"${widget.step.content}"}',
                      )),
                    ),
                    const SizedBox(width: 6),
                    _HoverAction(
                      icon: Icons.code,
                      label: 'View Raw',
                      onTap: () {},
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: isCrit
                      ? [
                          TextSpan(
                            text: widget.step.content,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                              color: Color(0xFFFF5F56),
                              fontFamily: 'monospace',
                            ),
                          )
                        ]
                      : _parseContent(widget.step.content),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HoverAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: const Color(0xFF8B949E)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF8B949E),
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Blinking Cursor ──────────────────────────────────────────────────────────

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: const Text(
        '_',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF58A6FF),
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
