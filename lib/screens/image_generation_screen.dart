import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class ImageGenerationScreen extends StatefulWidget {
  const ImageGenerationScreen({super.key});

  @override
  State<ImageGenerationScreen> createState() => _ImageGenerationScreenState();
}

class _ImageGenerationScreenState extends State<ImageGenerationScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;
  String? _error;
  final List<_GeneratedImage> _images = [];
  String _selectedSize = '1024x1024';

  final _sizes = ['1024x1024', '768x1344', '864x1152', '1344x768', '1152x864', '1440x720', '720x1440'];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generateImage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    final provider = context.read<ChatProvider>();
    if (provider.zai == null) {
      setState(() => _error = 'Cloud API belum terhubung. Buka Settings.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final response = await provider.zai!.images.create(
        prompt: prompt,
        size: _selectedSize,
      );

      if (!mounted) return;
      setState(() {
        for (int i = 0; i < response.imageData.length; i++) {
          _images.insert(0, _GeneratedImage(
            prompt: prompt,
            imageData: response.imageData[i],
            size: _selectedSize,
            timestamp: DateTime.now(),
          ));
        }
        _isGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal generate gambar: $e';
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Image Generation')),
      body: Column(
        children: [
          Expanded(
            child: _images.isEmpty
                ? _buildEmpty(theme)
                : _buildGallery(theme),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13))),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onErrorContainer, size: 18),
                    onPressed: () => setState(() => _error = null),
                  ),
                ],
              ),
            ),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Buat Gambar dengan AI', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Masukkan deskripsi gambar yang ingin Anda buat.\nMenggunakan CogView-3-Plus model.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildGallery(ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final img = _images[index];
        return GestureDetector(
          onTap: () => _showImageDetail(context, img),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (img.imageData.startsWith('http'))
                  Image.network(img.imageData, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                    Center(child: Icon(Icons.broken_image, color: theme.colorScheme.outline)))
                else
                  Center(child: Icon(Icons.image, size: 40, color: theme.colorScheme.primary.withValues(alpha: 0.5))),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
                    ),
                    child: Text(
                      img.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageDetail(BuildContext context, _GeneratedImage img) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detail Gambar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prompt:', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(img.prompt),
            const SizedBox(height: 8),
            Text('Size: ${img.size}'),
            Text('Waktu: ${img.timestamp.toString().substring(0, 19)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () {
            Clipboard.setData(ClipboardData(text: img.prompt));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prompt disalin')));
            Navigator.pop(ctx);
          }, child: const Text('Salin Prompt')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Size selector
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _sizes.map((size) {
                final isSelected = size == _selectedSize;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(size, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: _isGenerating ? null : (_) => setState(() => _selectedSize = size),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promptController,
                  decoration: InputDecoration(
                    hintText: 'Deskripsikan gambar...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    suffixIcon: _promptController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { _promptController.clear(); setState(() {}); })
                        : null,
                  ),
                  onSubmitted: (_) => _generateImage(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isGenerating ? null : _generateImage,
                icon: _isGenerating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome),
                tooltip: 'Generate',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GeneratedImage {
  final String prompt;
  final String imageData;
  final String size;
  final DateTime timestamp;

  _GeneratedImage({required this.prompt, required this.imageData, required this.size, required this.timestamp});
}
