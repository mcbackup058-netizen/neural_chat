import 'dart:math' as math;
import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final bool isGenerating;
  final VoidCallback? onStop;

  const TypingIndicator({super.key, required this.isGenerating, this.onStop});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isGenerating) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        final t = _controller.value;
                        final dotT = (t + index * 0.33) % 1.0;
                        final bounce = (math.sin(dotT * 2 * math.pi) + 1) / 2;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          child: Transform.translate(
                            offset: Offset(0, -6 * bounce),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.4 + 0.6 * bounce),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(width: 12),
                if (widget.onStop != null)
                  GestureDetector(
                    onTap: widget.onStop,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.stop, size: 16, color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
