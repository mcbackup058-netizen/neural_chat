import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/model_selector.dart';
import '../widgets/typing_indicator.dart';
import 'settings_screen.dart';
import 'model_management_screen.dart';
import 'conversations_screen.dart';
import 'image_generation_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSelectBestMode();
    });
  }

  void _autoSelectBestMode() {
    final provider = context.read<ChatProvider>();
    if (provider.chatMode == ChatMode.local && !provider.hasLocalModel) {
      provider.setChatMode(ChatMode.cloud);
    }
    // Load last conversation or create new
    if (provider.historyService.conversations.isNotEmpty && provider.currentConversationId.isEmpty) {
      provider.loadConversation(provider.historyService.conversations.first.id);
    }
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
        title: const Text('Hapus Chat'),
        content: const Text('Yakin ingin menghapus semua pesan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () { context.read<ChatProvider>().clearChat(); Navigator.pop(context); },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _confirmNewChat() {
    if (context.read<ChatProvider>().messages.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat Baru'),
        content: const Text('Mulai percakapan baru? Chat saat ini akan disimpan di riwayat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () { context.read<ChatProvider>().newConversation(); Navigator.pop(context); },
            child: const Text('Buat Baru'),
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
        title: Consumer<ChatProvider>(
          builder: (context, provider, _) {
            final conv = provider.historyService.activeConversation;
            return Text(
              conv?.title ?? 'NeuralChat',
              style: const TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Chat Baru',
            onPressed: _confirmNewChat,
          ),
          const ModelSelectorWrapper(),
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
                  itemCount: chatProvider.messages.length + (chatProvider.isGenerating ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < chatProvider.messages.length) {
                      final message = chatProvider.messages[index];
                      final isLastAssistant = !message.isUser && index == chatProvider.messages.length - 1;
                      return MessageBubble(
                        message: message,
                        onRegenerate: isLastAssistant && !chatProvider.isGenerating
                            ? () => chatProvider.regenerateLastMessage()
                            : null,
                      );
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
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.psychology, size: 32, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Text('NeuralChat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('AI Chat Assistant v2.0', style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Chat'),
              subtitle: const Text('Percakapan saat ini'),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Riwayat Chat'),
              subtitle: const Text('Lihat semua percakapan'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Image Generation'),
              subtitle: const Text('Buat gambar dengan AI'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ImageGenerationScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              subtitle: const Text('API keys & preferensi'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.memory_outlined),
              title: const Text('Model Management'),
              subtitle: const Text('Kelola model GGUF'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelManagementScreen()));
              },
            ),
            const Divider(),
            Consumer<ChatProvider>(
              builder: (context, provider, _) {
                if (provider.activeModel == null) return const SizedBox.shrink();
                return ListTile(
                  leading: const Icon(Icons.memory, color: Colors.green),
                  title: Text(provider.activeModel!.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Model aktif'),
                  trailing: IconButton(
                    icon: const Icon(Icons.eject),
                    tooltip: 'Unload model',
                    onPressed: () async => await provider.unloadLocalModel(),
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primaryContainer, theme.colorScheme.secondaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(Icons.psychology, size: 52, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text('Selamat Datang di NeuralChat', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Asisten AI dengan GGUF local inference\ndan GLM Cloud API via z-ai-web-dev-sdk',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Status badges
            if (isCloudReady)
              _StatusBadge(icon: Icons.cloud_done, label: 'GLM Cloud API Connected', color: Colors.green, theme: theme),
            if (isLocalReady)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _StatusBadge(icon: Icons.memory, label: 'Local Model Loaded', color: Colors.teal, theme: theme),
              ),

            if (isCloudReady) ...[
              const SizedBox(height: 16),
              Text('Coba tanyakan sesuatu:', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _suggestionChip(context, 'Siapa kamu?', 'Siapa kamu?'),
                  _suggestionChip(context, 'Jelaskan Flutter', 'Jelaskan Flutter secara singkat'),
                  _suggestionChip(context, 'Kode Python', 'Buatkan contoh kode Python hello world'),
                  _suggestionChip(context, 'Cari berita', 'Cari berita terkini tentang teknologi AI'),
                  _suggestionChip(context, 'Tips coding', 'Berikan tips coding yang berguna'),
                  _suggestionChip(context, 'Penjelasan AI', 'Apa itu Machine Learning?'),
                ],
              ),
            ] else ...[
              _StatusBadge(icon: Icons.warning_amber, label: 'Atur API key di Settings untuk mulai chat', color: Colors.orange, theme: theme),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                icon: const Icon(Icons.settings),
                label: const Text('Buka Settings'),
              ),
            ],

            const SizedBox(height: 32),
            // Feature chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _featureChip(Icons.cloud, 'GLM Cloud', isCloudReady ? Colors.green : Colors.grey),
                _featureChip(Icons.memory, 'Local GGUF', isLocalReady ? Colors.green : Colors.grey),
                _featureChip(Icons.build_circle, 'MCP Tools', isCloudReady ? Colors.blue : Colors.grey),
                _featureChip(Icons.image, 'Image Gen', isCloudReady ? Colors.purple : Colors.grey),
                _featureChip(Icons.history, 'Chat History', Colors.amber),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(BuildContext context, String label, String prompt) {
    return ActionChip(
      avatar: Icon(Icons.chat_bubble_outline, size: 16, color: Theme.of(context).colorScheme.primary),
      label: Text(label),
      onPressed: () { _messageController.text = prompt; _sendMessage(); },
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }

  Widget _featureChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
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
            label: const Text('Stop'),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
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
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (chatProvider.messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: theme.colorScheme.onSurfaceVariant),
              tooltip: 'Hapus chat',
              onPressed: _confirmClearChat,
            ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: chatProvider.hasApiKey ? 'Ketik pesan...' : 'Atur API key di Settings',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            onPressed: chatProvider.isGenerating ? null : _sendMessage,
            icon: chatProvider.isGenerating
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                : const Icon(Icons.send_rounded),
            tooltip: 'Kirim',
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final ThemeData theme;

  const _StatusBadge({required this.icon, required this.label, required this.color, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}
