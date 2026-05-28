import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../models/model_config.dart';

class ModelManagementScreen extends StatefulWidget {
  const ModelManagementScreen({super.key});

  @override
  State<ModelManagementScreen> createState() => _ModelManagementScreenState();
}

class _ModelManagementScreenState extends State<ModelManagementScreen> {
  bool _isLoading = false;
  String? _loadingModelId;
  String? _error;

  Future<void> _pickAndAddModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf', 'bin'],
        dialogTitle: 'Select GGUF Model File',
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        if (!mounted) return;
        _showModelFormDialog(
          initialName: fileName.replaceAll('.gguf', '').replaceAll('.bin', ''),
          filePath: filePath,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to pick file: $e');
    }
  }

  Future<void> _showModelFormDialog({
    required String initialName,
    required String filePath,
    LocalModelConfig? existingModel,
  }) async {
    final nameController = TextEditingController(text: initialName);
    final contextSizeController = TextEditingController(
      text: (existingModel?.contextSize ?? 4096).toString(),
    );
    final maxTokensController = TextEditingController(
      text: (existingModel?.maxTokens ?? 2048).toString(),
    );
    final temperatureController = TextEditingController(
      text: (existingModel?.temperature ?? 0.7).toStringAsFixed(1),
    );
    final topPController = TextEditingController(
      text: (existingModel?.topP ?? 0.9).toStringAsFixed(1),
    );
    final gpuLayersController = TextEditingController(
      text: (existingModel?.gpuLayers ?? 0).toString(),
    );

    final isEditing = existingModel != null;
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Model' : 'Add Model'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isEditing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                filePath,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Model Name',
                        prefixIcon: Icon(Icons.label),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: contextSizeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Context Size',
                              prefixIcon: Icon(Icons.view_week),
                              border: OutlineInputBorder(),
                              hintText: '4096',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxTokensController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max Tokens',
                              prefixIcon: Icon(Icons.short_text),
                              border: OutlineInputBorder(),
                              hintText: '2048',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: temperatureController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Temperature',
                              prefixIcon: Icon(Icons.thermostat),
                              border: OutlineInputBorder(),
                              hintText: '0.7',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: topPController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Top P',
                              prefixIcon: Icon(Icons.tune),
                              border: OutlineInputBorder(),
                              hintText: '0.9',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: gpuLayersController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'GPU Layers',
                        prefixIcon: Icon(Icons.memory),
                        border: OutlineInputBorder(),
                        hintText: '0 (0 = CPU only)',
                        helperText: 'Number of layers to offload to GPU',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    // Validate inputs
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final contextSize =
                        int.tryParse(contextSizeController.text) ?? 4096;
                    final maxTokens =
                        int.tryParse(maxTokensController.text) ?? 2048;
                    final temperature =
                        double.tryParse(temperatureController.text) ?? 0.7;
                    final topP = double.tryParse(topPController.text) ?? 0.9;
                    final gpuLayers =
                        int.tryParse(gpuLayersController.text) ?? 0;

                    final settings = context.read<SettingsProvider>();

                    if (isEditing && existingModel != null) {
                      final updatedModel = existingModel.copyWith(
                        name: name,
                        contextSize: contextSize,
                        maxTokens: maxTokens,
                        temperature: temperature.clamp(0.0, 2.0),
                        topP: topP.clamp(0.0, 1.0),
                        gpuLayers: gpuLayers.clamp(0, 999),
                      );
                      settings.updateModel(updatedModel);
                    } else {
                      final newModel = LocalModelConfig(
                        id: const Uuid().v4(),
                        name: name,
                        filePath: filePath,
                        contextSize: contextSize,
                        maxTokens: maxTokens,
                        temperature: temperature.clamp(0.0, 2.0),
                        topP: topP.clamp(0.0, 1.0),
                        gpuLayers: gpuLayers.clamp(0, 999),
                      );
                      settings.addModel(newModel);
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: Text(isEditing ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    contextSizeController.dispose();
    maxTokensController.dispose();
    temperatureController.dispose();
    topPController.dispose();
    gpuLayersController.dispose();

    if (result == true && mounted) {
      setState(() => _error = null);
    }
  }

  Future<void> _loadModel(LocalModelConfig model) async {
    setState(() {
      _isLoading = true;
      _loadingModelId = model.id;
      _error = null;
    });

    try {
      final chatProvider = context.read<ChatProvider>();
      final success = await chatProvider.loadLocalModel(model);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadingModelId = null;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Model "${model.name}" loaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _error = chatProvider.lastError);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadingModelId = null;
        _error = 'Failed to load model: $e';
      });
    }
  }

  Future<void> _deleteModel(LocalModelConfig model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Remove "${model.name}" from the model list?\n\n'
            'Note: This only removes the configuration. The model file '
            'will not be deleted from storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final chatProvider = context.read<ChatProvider>();
      // Unload if this is the active model
      if (chatProvider.activeModelId == model.id) {
        await chatProvider.unloadLocalModel();
      }
      context.read<SettingsProvider>().removeModel(model.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Model Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _pickAndAddModel,
        icon: const Icon(Icons.add),
        label: const Text('Add Model'),
      ),
      body: Consumer2<SettingsProvider, ChatProvider>(
        builder: (context, settings, chatProvider, _) {
          final models = settings.models;

          if (models.isEmpty) {
            return _buildEmptyState(theme);
          }

          return Column(
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: theme.colorScheme.errorContainer,
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: theme.colorScheme.onErrorContainer, size: 18),
                        onPressed: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    final model = models[index];
                    final isActive = chatProvider.activeModelId == model.id;
                    final isThisLoading =
                        _isLoading && _loadingModelId == model.id;
                    final fileSize = _getFileSize(model.filePath);

                    return _ModelCard(
                      model: model,
                      isActive: isActive,
                      isLoading: isThisLoading,
                      fileSize: fileSize,
                      onLoad: () => _loadModel(model),
                      onEdit: () => _showModelFormDialog(
                        initialName: model.name,
                        filePath: model.filePath,
                        existingModel: model,
                      ),
                      onDelete: () => _deleteModel(model),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.memory_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Models Added',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the "Add Model" button to load a GGUF model file.\n\n'
              'Supported formats: .gguf, .bin',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFileSize(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        if (bytes >= 1073741824) {
          return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
        } else if (bytes >= 1048576) {
          return '${(bytes / 1048576).toStringAsFixed(1)} MB';
        } else {
          return '${(bytes / 1024).toStringAsFixed(1)} KB';
        }
      }
    } catch (_) {}
    return 'Unknown';
  }
}

class _ModelCard extends StatelessWidget {
  final LocalModelConfig model;
  final bool isActive;
  final bool isLoading;
  final String fileSize;
  final VoidCallback onLoad;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ModelCard({
    required this.model,
    required this.isActive,
    required this.isLoading,
    required this.fileSize,
    required this.onLoad,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isActive
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.memory,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              model.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'ACTIVE',
                                style:
                                    theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$fileSize  •  ctx: ${model.contextSize}  •  '
                        'temp: ${model.temperature}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'load':
                        onLoad();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isActive)
                      const PopupMenuItem(
                        value: 'load',
                        child: ListTile(
                          leading: Icon(Icons.play_arrow),
                          title: Text('Load Model'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit Parameters'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline,
                            color: Colors.red),
                        title: Text('Delete',
                            style: TextStyle(color: Colors.red)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isLoading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                'Loading model...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _ParamChip(
                    label: 'Max Tokens: ${model.maxTokens}',
                    icon: Icons.short_text),
                _ParamChip(
                    label: 'Top P: ${model.topP}',
                    icon: Icons.tune),
                _ParamChip(
                    label: 'GPU Layers: ${model.gpuLayers}',
                    icon: Icons.speed),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ParamChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ParamChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
