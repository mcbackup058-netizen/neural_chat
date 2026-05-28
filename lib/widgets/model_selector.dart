import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class ModelSelector extends StatelessWidget {
  const ModelSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final theme = Theme.of(context);

    return PopupMenuButton<ChatMode>(
      initialValue: provider.chatMode,
      onSelected: provider.setChatMode,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surface,
      elevation: 8,
      itemBuilder: (context) => [
        _buildMenuItem(context, ChatMode.local, Icons.memory, 'Local Model',
            provider.hasLocalModel ? '${provider.activeModel?.name ?? "Loaded"}' : 'No model loaded',
            provider.hasLocalModel),
        _buildMenuItem(context, ChatMode.cloud, Icons.cloud, 'GLM Cloud',
            provider.hasApiKey ? 'API Connected' : 'No API key',
            provider.hasApiKey),
        _buildMenuItem(context, ChatMode.auto, Icons.auto_awesome, 'Auto (Recommended)',
            'Falls back to cloud when needed', true),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getModeIcon(provider.chatMode), size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              _getModeLabel(provider.chatMode),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<ChatMode> _buildMenuItem(
    BuildContext context,
    ChatMode mode,
    IconData icon,
    String title,
    String subtitle,
    bool enabled,
  ) {
    final theme = Theme.of(context);
    return PopupMenuItem(
      value: mode,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, color: enabled ? theme.colorScheme.primary : theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
                  color: enabled ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.outline,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getModeIcon(ChatMode mode) => switch (mode) {
    ChatMode.local => Icons.memory,
    ChatMode.cloud => Icons.cloud,
    ChatMode.auto => Icons.auto_awesome,
  };

  String _getModeLabel(ChatMode mode) => switch (mode) {
    ChatMode.local => 'Local',
    ChatMode.cloud => 'GLM Cloud',
    ChatMode.auto => 'Auto',
  };
}
