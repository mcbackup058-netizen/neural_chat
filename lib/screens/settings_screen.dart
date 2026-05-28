import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/chat_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _apiUrlController;
  bool _obscureApiKey = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _apiKeyController = TextEditingController(text: settings.glmApiKey);
    _apiUrlController = TextEditingController(text: settings.glmApiUrl);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey(String value, SettingsProvider settings) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Save the key in settings
      settings.setGlmApiKey(value);

      // Reinitialize the ChatProvider's ZAI service with the new key
      if (mounted) {
        final chatProvider = context.read<ChatProvider>();
        await chatProvider.reinitializeServices();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value.isEmpty ? 'API key removed' : 'API key saved and connected'),
            backgroundColor: value.isEmpty ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save API key: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── GLM API Section ──────────────────────────────────────
              _SectionHeader(
                icon: Icons.cloud_outlined,
                title: 'GLM API Configuration',
                subtitle: 'Connect to GLM cloud service via z-ai-web-dev-sdk',
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureApiKey,
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          hintText: 'Enter your GLM API key (id.secret format)',
                          prefixIcon: const Icon(Icons.key_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _obscureApiKey
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureApiKey = !_obscureApiKey;
                                  });
                                },
                              ),
                              IconButton(
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.check_circle_outline),
                                tooltip: 'Save & Connect',
                                onPressed: () => _saveApiKey(
                                    _apiKeyController.text.trim(), settings),
                              ),
                            ],
                          ),
                        ),
                        onChanged: (value) => settings.setGlmApiKey(value),
                        onSubmitted: (_) => _saveApiKey(
                            _apiKeyController.text.trim(), settings),
                      ),
                      const SizedBox(height: 4),
                      Consumer<ChatProvider>(
                        builder: (context, chatProvider, _) {
                          final connected = chatProvider.zai != null;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  connected
                                      ? Icons.check_circle
                                      : Icons.info_outline,
                                  size: 14,
                                  color: connected
                                      ? Colors.green
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  connected
                                      ? 'Connected to GLM API'
                                      : 'Enter API key to connect',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: connected
                                        ? Colors.green
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _apiUrlController,
                        decoration: const InputDecoration(
                          labelText: 'API Base URL',
                          hintText: 'https://open.bigmodel.cn/api/paas/v4',
                          prefixIcon: Icon(Icons.link),
                          border: OutlineInputBorder(),
                          helperText: 'Base URL for the GLM API',
                        ),
                        onChanged: (value) => settings.setGlmApiUrl(value),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Cloud Fallback'),
                        subtitle: const Text(
                          'Use GLM cloud when local model fails or is unavailable',
                        ),
                        value: settings.useCloudFallback,
                        onChanged: (value) => settings.setUseCloudFallback(value),
                        contentPadding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Default Parameters Section ──────────────────────────
              _SectionHeader(
                icon: Icons.tune,
                title: 'Default Parameters',
                subtitle: 'Inference settings for new conversations',
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Temperature
                      Row(
                        children: [
                          const Icon(Icons.thermostat_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Temperature',
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  '${settings.defaultTemperature.toStringAsFixed(1)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: settings.defaultTemperature,
                        min: 0.0,
                        max: 2.0,
                        divisions: 20,
                        label: settings.defaultTemperature.toStringAsFixed(1),
                        onChanged: (value) =>
                            settings.setDefaultTemperature(value),
                      ),
                      const Divider(),
                      // Context Size
                      Row(
                        children: [
                          const Icon(Icons.view_week_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Context Size',
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  '${settings.defaultContextSize} tokens',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: settings.defaultContextSize,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.format_list_numbered),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 2048,
                            child: Text('2048 tokens'),
                          ),
                          DropdownMenuItem(
                            value: 4096,
                            child: Text('4096 tokens'),
                          ),
                          DropdownMenuItem(
                            value: 8192,
                            child: Text('8192 tokens'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            settings.setDefaultContextSize(value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      // Max Tokens
                      Row(
                        children: [
                          const Icon(Icons.short_text),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Max Tokens',
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  '${settings.defaultMaxTokens}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: settings.defaultMaxTokens.toDouble(),
                        min: 256,
                        max: 8192,
                        divisions: 31,
                        label: '${settings.defaultMaxTokens}',
                        onChanged: (value) =>
                            settings.setDefaultMaxTokens(value.round()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── About Section ───────────────────────────────────────
              _SectionHeader(
                icon: Icons.info_outline,
                title: 'About',
                subtitle: 'Application information',
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.apps),
                        title: const Text('NeuralChat'),
                        subtitle: const Text('v1.0.1'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                      ),
                      const Divider(height: 1),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'NeuralChat is a privacy-focused AI chat application that '
                          'runs GGUF models directly on your device. It supports local '
                          'inference via llama.cpp with GLM cloud fallback and '
                          'MCP (Model Context Protocol) tool integration for extended '
                          'capabilities via z-ai-web-dev-sdk.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: const Text('Flutter'),
                            avatar: const Icon(Icons.flutter_dash, size: 16),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: const Text('z-ai-web-dev-sdk'),
                            avatar: const Icon(Icons.cloud, size: 16),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: const Text('Provider'),
                            avatar:
                                const Icon(Icons.data_object, size: 16),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
