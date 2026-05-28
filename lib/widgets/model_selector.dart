import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';

class ModelSelector extends StatelessWidget {
  const ModelSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surface,
      elevation: 8,
      itemBuilder: (context) => [
        // Mode selection section
        const PopupMenuItem(enabled: false, height: 32, child: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        _buildModeItem(context, 'local', Icons.memory, 'Local Model',
            provider.hasLocalModel ? '${provider.activeModel?.name ?? "Loaded"}' : 'No model loaded',
            provider.hasLocalModel, provider.chatMode == ChatMode.local),
        _buildModeItem(context, 'cloud', Icons.cloud, 'GLM Cloud',
            settings.cloudModel.toUpperCase(), true, provider.chatMode == ChatMode.cloud),
        _buildModeItem(context, 'auto', Icons.auto_awesome, 'Auto',
            'Falls back to cloud', true, provider.chatMode == ChatMode.auto),
        const PopupMenuDivider(height: 8),
        // Cloud model selection
        const PopupMenuItem(enabled: false, height: 32, child: Text('Cloud Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        _buildCloudModelItem(context, 'glm-4-plus', settings, provider.chatMode == ChatMode.cloud),
        _buildCloudModelItem(context, 'glm-4-flash', settings, provider.chatMode == ChatMode.cloud),
        _buildCloudModelItem(context, 'glm-4v-flash', settings, provider.chatMode == ChatMode.cloud),
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
            Icon(_modeIcon(provider.chatMode), size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              _modeLabel(provider.chatMode),
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

  static IconData _modeIcon(ChatMode mode) => switch (mode) {
    ChatMode.local => Icons.memory,
    ChatMode.cloud => Icons.cloud,
    ChatMode.auto => Icons.auto_awesome,
  };

  static String _modeLabel(ChatMode mode) => switch (mode) {
    ChatMode.local => 'Local',
    ChatMode.cloud => 'GLM Cloud',
    ChatMode.auto => 'Auto',
  };

  PopupMenuItem<String> _buildModeItem(
    BuildContext context,
    String value,
    IconData icon,
    String title,
    String subtitle,
    bool enabled,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    return PopupMenuItem(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.outline),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: enabled ? theme.colorScheme.onSurface : theme.colorScheme.outline,
                )),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
                  color: enabled ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.outline,
                  fontSize: 11,
                )),
              ],
            ),
          ),
          if (isSelected) Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildCloudModelItem(
    BuildContext context,
    String model,
    SettingsProvider settings,
    bool isCloudActive,
  ) {
    final theme = Theme.of(context);
    final isSelected = settings.cloudModel == model;
    final descriptions = {
      'glm-4-plus': 'Most capable, best quality',
      'glm-4-flash': 'Fast & efficient',
      'glm-4v-flash': 'Vision + text multimodal',
    };
    return PopupMenuItem(
      value: 'model_$model',
      onTap: isCloudActive ? () {
        settings.setCloudModel(model);
        context.read<ChatProvider>().updateCloudModel(model);
      } : null,
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.secondary : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.circle, size: 8, color: isSelected ? theme.colorScheme.onSecondary : Colors.transparent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(model, style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                )),
                Text(descriptions[model] ?? '', style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Handle mode selection in ChatScreen wrapper
class ModelSelectorWrapper extends StatelessWidget {
  const ModelSelectorWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      return PopupMenuButton<String>(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
        onSelected: (value) {
          if (value == 'local' || value == 'cloud' || value == 'auto') {
            final mode = ChatMode.values.firstWhere((m) => m.name == value);
            context.read<ChatProvider>().setChatMode(mode);
          }
        },
        itemBuilder: (context) {
          final provider = context.watch<ChatProvider>();
          final settings = context.watch<SettingsProvider>();
          return [
            const PopupMenuItem(enabled: false, height: 32, child: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            PopupMenuItem(
              value: 'local',
              enabled: provider.hasLocalModel,
              child: _modeRow(context, Icons.memory, 'Local Model', provider.chatMode == ChatMode.local),
            ),
            PopupMenuItem(
              value: 'cloud',
              child: _modeRow(context, Icons.cloud, 'GLM Cloud (${settings.cloudModel})', provider.chatMode == ChatMode.cloud),
            ),
            PopupMenuItem(
              value: 'auto',
              child: _modeRow(context, Icons.auto_awesome, 'Auto', provider.chatMode == ChatMode.auto),
            ),
            const PopupMenuDivider(height: 8),
            const PopupMenuItem(enabled: false, height: 32, child: Text('Cloud Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            PopupMenuItem(
              value: 'model_glm-4-plus',
              onTap: () { settings.setCloudModel('glm-4-plus'); provider.updateCloudModel('glm-4-plus'); },
              child: _modelRow(context, 'glm-4-plus', 'Most capable', settings.cloudModel == 'glm-4-plus'),
            ),
            PopupMenuItem(
              value: 'model_glm-4-flash',
              onTap: () { settings.setCloudModel('glm-4-flash'); provider.updateCloudModel('glm-4-flash'); },
              child: _modelRow(context, 'glm-4-flash', 'Fast & efficient', settings.cloudModel == 'glm-4-flash'),
            ),
            PopupMenuItem(
              value: 'model_glm-4v-flash',
              onTap: () { settings.setCloudModel('glm-4v-flash'); provider.updateCloudModel('glm-4v-flash'); },
              child: _modelRow(context, 'glm-4v-flash', 'Multimodal (vision)', settings.cloudModel == 'glm-4v-flash'),
            ),
          ];
        },
        child: _buildSelectorChip(context),
      );
    });
  }

  Widget _buildSelectorChip(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final theme = Theme.of(context);
    final icon = switch (provider.chatMode) {
      ChatMode.local => Icons.memory,
      ChatMode.cloud => Icons.cloud,
      ChatMode.auto => Icons.auto_awesome,
    };
    final label = switch (provider.chatMode) {
      ChatMode.local => 'Local',
      ChatMode.cloud => 'GLM Cloud',
      ChatMode.auto => 'Auto',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _modeRow(BuildContext context, IconData icon, String label, bool selected) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: selected ? theme.colorScheme.primary : theme.colorScheme.outline),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ))),
        if (selected) Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
      ],
    );
  }

  Widget _modelRow(BuildContext context, String model, String desc, bool selected) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? theme.colorScheme.secondary : Colors.transparent,
            border: Border.all(color: selected ? theme.colorScheme.secondary : theme.colorScheme.outline, width: 1.5),
          ),
          child: selected ? Icon(Icons.check, size: 12, color: theme.colorScheme.onSecondary) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(model, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
              Text(desc, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
