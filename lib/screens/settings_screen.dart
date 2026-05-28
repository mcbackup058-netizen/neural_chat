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
  late TextEditingController _systemPromptController;
  bool _obscureApiKey = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _apiKeyController = TextEditingController(text: settings.glmApiKey);
    _apiUrlController = TextEditingController(text: settings.glmApiUrl);
    _systemPromptController = TextEditingController(text: settings.systemPrompt);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiUrlController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey(String value, SettingsProvider settings) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      settings.setGlmApiKey(value);
      if (mounted) {
        await context.read<ChatProvider>().reinitializeServices();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value.isEmpty ? 'API key dihapus' : 'API key tersimpan & terhubung'),
            backgroundColor: value.isEmpty ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal simpan API key: $e'), backgroundColor: Colors.red),
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
              // GLM API Section
              _SectionHeader(icon: Icons.cloud_outlined, title: 'GLM API Configuration', subtitle: 'Koneksi ke GLM cloud service'),
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
                          hintText: 'Masukkan GLM API key (id.secret)',
                          prefixIcon: const Icon(Icons.key_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(_obscureApiKey ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                              ),
                              IconButton(
                                icon: _isSaving
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.check_circle_outline),
                                tooltip: 'Simpan & Hubungkan',
                                onPressed: () => _saveApiKey(_apiKeyController.text.trim(), settings),
                              ),
                            ],
                          ),
                        ),
                        onChanged: (value) => settings.setGlmApiKey(value),
                        onSubmitted: (_) => _saveApiKey(_apiKeyController.text.trim(), settings),
                      ),
                      const SizedBox(height: 4),
                      Consumer<ChatProvider>(
                        builder: (context, chatProvider, _) {
                          final connected = chatProvider.zai != null;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(connected ? Icons.check_circle : Icons.info_outline, size: 14, color: connected ? Colors.green : theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text(
                                  connected ? 'Terhubung ke GLM API' : 'Masukkan API key untuk terhubung',
                                  style: TextStyle(color: connected ? Colors.green : theme.colorScheme.onSurfaceVariant, fontSize: 12),
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
                          helperText: 'Base URL untuk GLM API',
                        ),
                        onChanged: (value) => settings.setGlmApiUrl(value),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Cloud Fallback'),
                        subtitle: const Text('Gunakan GLM cloud saat local model gagal'),
                        value: settings.useCloudFallback,
                        onChanged: (value) => settings.setUseCloudFallback(value),
                        contentPadding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: theme.colorScheme.outlineVariant)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // System Prompt
              _SectionHeader(icon: Icons.edit_note, title: 'System Prompt', subtitle: 'Instruksi kustom untuk AI'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _systemPromptController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'System Prompt',
                          hintText: 'Contoh: Kamu adalah asisten programming...',
                          border: OutlineInputBorder(),
                          helperText: 'Kosongkan untuk menggunakan default',
                        ),
                        onChanged: (value) => settings.setSystemPrompt(value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Parameters
              _SectionHeader(icon: Icons.tune, title: 'Parameter Default', subtitle: 'Pengaturan inferensi'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Temperature
                      Row(children: [
                        const Icon(Icons.thermostat_outlined),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Temperature', style: theme.textTheme.titleSmall),
                          Text('${settings.defaultTemperature.toStringAsFixed(1)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                        ])),
                      ]),
                      Slider(value: settings.defaultTemperature, min: 0.0, max: 2.0, divisions: 20, label: settings.defaultTemperature.toStringAsFixed(1), onChanged: (v) => settings.setDefaultTemperature(v)),
                      const Divider(),
                      // Max Tokens
                      Row(children: [
                        const Icon(Icons.short_text),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Max Tokens', style: theme.textTheme.titleSmall),
                          Text('${settings.defaultMaxTokens}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                        ])),
                      ]),
                      Slider(value: settings.defaultMaxTokens.toDouble(), min: 256, max: 8192, divisions: 31, label: '${settings.defaultMaxTokens}', onChanged: (v) => settings.setDefaultMaxTokens(v.round())),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // About
              _SectionHeader(icon: Icons.info_outline, title: 'Tentang', subtitle: 'Informasi aplikasi'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(leading: const Icon(Icons.apps), title: const Text('NeuralChat'), subtitle: const Text('v2.0.0'), trailing: const Icon(Icons.chevron_right, size: 20)),
                      const Divider(height: 1),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'NeuralChat adalah aplikasi chat AI yang berfokus pada privasi. '
                          'Mendukung inferensi GGUF lokal via llama.cpp dengan fallback GLM Cloud '
                          'dan integrasi MCP (Model Context Protocol) melalui z-ai-web-dev-sdk.\n\n'
                          'Fitur: Chat History, Image Generation, Cloud Model Selection, '
                          'Custom System Prompt, dan MCP Tools (web search, code execute, '
                          'image analysis, knowledge search).',
                          style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _techChip('Flutter'),
                          _techChip('z-ai-web-dev-sdk'),
                          _techChip('Provider'),
                          _techChip('Markdown'),
                          _techChip('CogView-3-Plus'),
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

  Widget _techChip(String label) {
    return Chip(label: Text(label, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact);
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]),
      ],
    );
  }
}
