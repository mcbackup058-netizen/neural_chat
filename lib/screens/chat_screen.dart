import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/model_selector.dart';
import '../widgets/typing_indicator.dart';
import 'settings_screen.dart';
import 'model_management_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-detect best mode on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSelectBestMode();
    });
  }

  void _autoSelectBestMode() {
    final provider = context.read<ChatProvider>();
    // If mode is Local but no model is loaded, switch to Cloud
    if (provider.chatMode == ChatMode.local && !provider.hasLocalModel) {
      provider.setChatMode(ChatMode.cloud);
    }
    // If mode is auto and no model, still show cloud-ready message
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<ChatProvider>();
    provider.sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<ChatProvider>().clearChat();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NeuralChat'),
        actions: const [
          ModelSelector(),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.messages.isEmpty && !chatProvider.isGenerating) {
            return _buildEmptyState(chatProvider);
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  itemCount: chatProvider.messages.length +
                      (chatProvider.isGenerating ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < chatProvider.messages.length) {
                      final message = chatProvider.messages[index];
                      return MessageBubble(message: message);
                    }
                    return TypingIndicator(
                      isGenerating: true,
                      onStop: () => chatProvider.stopGeneration(),
                    );
                  },
                ),
              ),
              if (chatProvider.isGenerating) _buildStopBar(chatProvider),
              _buildInputArea(chatProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(
                      Icons.psychology,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'NeuralChat',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Local & Cloud AI Chat',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Chat'),
              subtitle: const Text('Current conversation'),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              subtitle: const Text('API keys & preferences'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.memory_outlined),
              title: const Text('Model Management'),
              subtitle: const Text('Add, edit & manage models'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ModelManagementScreen()),
                );
              },
            ),
            const Divider(),
            Consumer<ChatProvider>(
              builder: (context, provider, _) {
                if (provider.activeModel == null) return const SizedBox.shrink();
                return ListTile(
                  leading: const Icon(Icons.memory, color: Colors.green),
                  title: Text(
                    provider.activeModel!.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Active model'),
                  trailing: IconButton(
                    icon: const Icon(Icons.eject),
                    tooltip: 'Unload model',
                    onPressed: () async {
                      await provider.unloadLocalModel();
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ChatProvider chatProvider) {
    final theme = Theme.of(context);
    final isCloudReady = chatProvider.hasApiKey;
    final isLocalReady = chatProvider.hasLocalModel;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.psychology,
                size: 64,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to NeuralChat',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'AI chat assistant dengan GGUF local inference\n'
              'dan GLM cloud fallback via z-ai-web-dev-sdk.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Status indicators
            if (isCloudReady)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_done, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'GLM Cloud API Connected',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Quick-start suggestions
            if (isCloudReady) ...[
              Text(
                'Coba tanyakan sesuatu:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _SuggestionChip(
                    text: 'Siapa kamu?',
                    onTap: () {
                      _messageController.text = 'Siapa kamu?';
                      _sendMessage();
                    },
                    theme: theme,
                  ),
                  _SuggestionChip(
                    text: 'Jelaskan Flutter',
                    onTap: () {
                      _messageController.text = 'Jelaskan Flutter secara singkat';
                      _sendMessage();
                    },
                    theme: theme,
                  ),
                  _SuggestionChip(
                    text: 'Buatkan kode',
                    onTap: () {
                      _messageController.text = 'Buatkan contoh kode Python hello world';
                      _sendMessage();
                    },
                    theme: theme,
                  ),
                  _SuggestionChip(
                    text: 'Cari berita terkini',
                    onTap: () {
                      _messageController.text = 'Cari berita terkini tentang teknologi AI';
                      _sendMessage();
                    },
                    theme: theme,
                  ),
                ],
              ),
            ] else ...[
              // No API key configured
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'API key belum dikonfigurasi. Buka Settings untuk mengatur.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.settings),
                label: const Text('Buka Settings'),
              ),
            ],

            const SizedBox(height: 40),

            // Feature chips (smaller, at bottom)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _FeatureChip(
                  icon: Icons.cloud,
                  label: 'GLM Cloud',
                  color: isCloudReady ? Colors.green : Colors.grey,
                ),
                _FeatureChip(
                  icon: Icons.memory,
                  label: 'Local GGUF',
                  color: isLocalReady ? Colors.green : Colors.grey,
                ),
                _FeatureChip(
                  icon: Icons.build_circle,
                  label: 'MCP Tools',
                  color: isCloudReady ? Colors.blue : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopBar(ChatProvider chatProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => chatProvider.stopGeneration(),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop generating'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ChatProvider chatProvider) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (chatProvider.messages.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_sweep_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Clear chat',
              onPressed: _confirmClearChat,
            ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: chatProvider.hasApiKey
                      ? 'Ketik pesan...'
                      : 'Atur API key di Settings terlebih dahulu',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                keyboardType: TextInputType.multiline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed:
                chatProvider.isGenerating ? null : _sendMessage,
            icon: chatProvider.isGenerating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            tooltip: 'Send message',
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final ThemeData theme;

  const _SuggestionChip({
    required this.text,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(Icons.chat_bubble_outline,
          size: 16, color: theme.colorScheme.primary),
      label: Text(text),
      onPressed: onTap,
      side: BorderSide(color: theme.colorScheme.outlineVariant),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label,
          style: TextStyle(color: color, fontSize: 12)),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
    );
  }
}
