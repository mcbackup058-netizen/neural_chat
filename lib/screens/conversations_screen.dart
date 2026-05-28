import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Chat'),
        actions: [
          Consumer<ChatProvider>(
            builder: (context, provider, _) {
              if (provider.historyService.conversations.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Hapus semua',
                onPressed: () => _showDeleteAllDialog(context, provider),
              );
            },
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          final conversations = provider.historyService.conversations;
          if (conversations.isEmpty) return _buildEmpty(context);
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conv = conversations[index];
              final isActive = conv.id == provider.currentConversationId;
              return _ConversationCard(
                conversation: conv,
                isActive: isActive,
                onTap: () {
                  provider.loadConversation(conv.id);
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                onPin: () => provider.historyService.togglePin(conv.id),
                onDelete: () async {
                  await provider.deleteConversation(conv.id);
                },
                onRename: () => _showRenameDialog(context, conv),
                onExport: () => _exportConversation(context, conv),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Belum ada riwayat chat', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Percakapan Anda akan otomatis tersimpan di sini.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _showDeleteAllDialog(BuildContext context, ChatProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Riwayat'),
        content: const Text('Yakin ingin menghapus semua riwayat chat?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              final ids = provider.historyService.conversations.map((c) => c.id).toList();
              for (final id in ids) {
                await provider.deleteConversation(id);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, dynamic conv) {
    final controller = TextEditingController(text: conv.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Judul', border: OutlineInputBorder()),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              context.read<ChatProvider>().historyService.renameConversation(conv.id, value.trim());
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<ChatProvider>().historyService.renameConversation(conv.id, controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _exportConversation(BuildContext context, dynamic conv) {
    final text = context.read<ChatProvider>().historyService.exportConversation(conv.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chat "${conv.title}" diekspor ke clipboard (${text.length} karakter)'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final dynamic conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback onExport;

  const _ConversationCard({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onPin,
    required this.onDelete,
    required this.onRename,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msgCount = (conversation.messages as List).length;
    final time = conversation.updatedAt as DateTime;
    final dateStr = DateFormat('dd/MM HH:mm').format(time);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isActive ? BorderSide(color: theme.colorScheme.primary, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: isActive ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  conversation.isPinned ? Icons.push_pin : Icons.chat_bubble_outline,
                  size: 20,
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(10)),
                            child: Text('AKTIF', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('$msgCount pesan  •  $dateStr', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'pin': onPin(); break;
                    case 'rename': onRename(); break;
                    case 'export': onExport(); break;
                    case 'delete': onDelete(); break;
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'pin', child: ListTile(leading: Icon(conversation.isPinned ? Icons.push_pin : Icons.push_pin_outlined), title: Text(conversation.isPinned ? 'Unpin' : 'Pin'), dense: true, contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Rename'), dense: true, contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.file_download_outlined), title: Text('Ekspor'), dense: true, contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Hapus', style: TextStyle(color: Colors.red)), dense: true, contentPadding: EdgeInsets.zero)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
