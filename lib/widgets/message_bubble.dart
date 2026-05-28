import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRegenerate;

  const MessageBubble({super.key, required this.message, this.onRegenerate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Source badge + timestamp for assistant messages
            if (!isUser && message.status == MessageStatus.complete)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SourceBadge(source: message.source),
                    if (message.responseTimeMs > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${(message.responseTimeMs / 1000).toStringAsFixed(1)}s',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Message bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isUser
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          message.content,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onPrimary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    )
                  : _buildAssistantContent(theme),
            ),

            // Error indicator
            if (message.status == MessageStatus.error)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 14, color: theme.colorScheme.error),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        message.errorMessage ?? 'Error',
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Action buttons for completed assistant messages
            if (!isUser && message.status == MessageStatus.complete && message.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionButton(
                      icon: Icons.copy,
                      tooltip: 'Salin',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: message.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Disalin ke clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    if (onRegenerate != null)
                      _ActionButton(
                        icon: Icons.refresh,
                        tooltip: 'Regenerasi',
                        onTap: onRegenerate,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildAssistantContent(ThemeData theme) {
    if (message.status == MessageStatus.streaming) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: MarkdownBody(
              data: message.content.isEmpty ? '...' : message.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: _StreamingDots(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: message.content,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatTime(message.timestamp),
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final MessageSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (source) {
      MessageSource.local => (Icons.memory, 'Local', Colors.green),
      MessageSource.cloud => (Icons.cloud, 'GLM Cloud', Colors.blue),
      MessageSource.system => (Icons.info, 'System', Colors.orange),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
      ),
    );
  }
}

class _StreamingDots extends StatefulWidget {
  @override
  State<_StreamingDots> createState() => _StreamingDotsState();
}

class _StreamingDotsState extends State<_StreamingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final opacity = 0.3 + 0.7 * ((math.sin(t * 2 * math.pi + i * 0.8) + 1) / 2);
            return Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
