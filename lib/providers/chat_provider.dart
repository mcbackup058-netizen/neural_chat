import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/model_config.dart';
import '../services/local_inference_service.dart';
import '../services/z_ai_web_dev_sdk.dart';
import '../services/mcp_service.dart';
import '../services/settings_service.dart';

enum ChatMode { local, cloud, auto }

class ChatProvider extends ChangeNotifier {
  final SettingsService _settings;
  ZAI? _zai;
  McpService? _mcpService;
  bool _servicesInitialized = false;

  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  ChatMode _chatMode = ChatMode.cloud;
  String? _activeModelId;
  LocalModelConfig? _activeModel;
  String _lastError = '';
  bool _isInitComplete = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  bool get isInitComplete => _isInitComplete;
  ChatMode get chatMode => _chatMode;
  String? get activeModelId => _activeModelId;
  LocalModelConfig? get activeModel => _activeModel;
  String get lastError => _lastError;
  bool get hasLocalModel => _activeModel != null && _activeModel!.isLoaded;
  bool get hasApiKey => _settings.glmApiKey.isNotEmpty;
  bool get isCloudReady => _zai != null && _mcpService != null;
  ZAI? get zai => _zai;

  ChatProvider(this._settings) {
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      if (_settings.glmApiKey.isNotEmpty) {
        _zai = await ZAI.create(apiKey: _settings.glmApiKey);
        _mcpService = McpService(zai: _zai!);
        _servicesInitialized = true;
      }
    } catch (e) {
      debugPrint('Failed to initialize ZAI service: $e');
      _lastError = 'Gagal inisialisasi cloud API: $e';
    } finally {
      _isInitComplete = true;
      notifyListeners();
    }
  }

  Future<void> reinitializeServices() async {
    _zai?.dispose();
    _zai = null;
    _mcpService = null;
    _servicesInitialized = false;
    _lastError = '';
    await _initServices();
  }

  void setChatMode(ChatMode mode) {
    _chatMode = mode;
    notifyListeners();
  }

  Future<bool> loadLocalModel(LocalModelConfig config) async {
    try {
      _lastError = '';
      notifyListeners();

      final service = LocalInferenceService.instance;
      await service.loadModel(config);

      _activeModel = config.copyWith(isLoaded: true);
      _activeModelId = config.id;
      _settings.activeModelId = config.id;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Gagal memuat model: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> unloadLocalModel() async {
    await LocalInferenceService.instance.unloadModel();
    _activeModel = null;
    _activeModelId = null;
    _settings.activeModelId = '';
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // Ensure services are initialized before sending
    if (!_servicesInitialized) {
      await _initServices();
    }

    // Add user message
    final userMsg = ChatMessage(
      content: content.trim(),
      isUser: true,
    );
    _messages.add(userMsg);
    notifyListeners();

    // Create assistant message placeholder
    final assistantMsg = ChatMessage(
      content: '',
      isUser: false,
      status: MessageStatus.streaming,
    );
    _messages.add(assistantMsg);
    notifyListeners();

    _isGenerating = true;
    _lastError = '';
    notifyListeners();

    try {
      final useLocal = _shouldUseLocal();

      if (useLocal && hasLocalModel) {
        await _generateLocal(content, assistantMsg);
      } else if (isCloudReady) {
        await _generateCloud(content, assistantMsg);
      } else if (hasApiKey && !isCloudReady) {
        // API key exists but init failed, try again
        await reinitializeServices();
        if (isCloudReady) {
          await _generateCloud(content, assistantMsg);
        } else {
          _setError(assistantMsg, 'Gagal terhubung ke cloud API. Periksa API key di Settings.');
        }
      } else if (!hasApiKey) {
        _setError(assistantMsg, 'API key belum dikonfigurasi. Buka Settings untuk mengatur API key.');
      } else {
        _setError(assistantMsg, 'Tidak ada model atau API yang tersedia.');
      }
    } catch (e) {
      _setError(assistantMsg, 'Error: $e');
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  void _setError(ChatMessage msg, String error) {
    _updateMessage(msg,
        content: error,
        status: MessageStatus.error,
        errorMessage: error);
    _lastError = error;
  }

  bool _shouldUseLocal() {
    switch (_chatMode) {
      case ChatMode.local:
        return true;
      case ChatMode.cloud:
        return false;
      case ChatMode.auto:
        return hasLocalModel;
    }
  }

  Future<void> _generateLocal(String prompt, ChatMessage msg) async {
    final service = LocalInferenceService.instance;
    final buffer = StringBuffer();

    try {
      await for (final token in service.generate(prompt,
          maxTokens: _activeModel?.maxTokens ?? 2048)) {
        buffer.write(token);
        _updateMessage(msg, content: buffer.toString());
      }
      _updateMessage(msg,
          content: buffer.toString(),
          status: MessageStatus.complete,
          source: MessageSource.local);
    } catch (e) {
      if (_settings.useCloudFallback && isCloudReady) {
        buffer.clear();
        _updateMessage(msg, content: '', status: MessageStatus.streaming);
        await _generateCloud(prompt, msg);
      } else {
        rethrow;
      }
    }
  }

  /// Generate via z-ai-web-dev-sdk cloud (GLM + MCP).
  Future<void> _generateCloud(String prompt, ChatMessage msg) async {
    if (_zai == null || _mcpService == null) {
      throw Exception('Cloud API belum siap. Periksa Settings.');
    }

    final history = _buildConversationHistory(prompt);
    final buffer = StringBuffer();

    try {
      final stream = _mcpService!.chatWithMcp(
        messages: history,
        temperature: _settings.defaultTemperature,
        maxTokens: _settings.defaultMaxTokens,
      );

      await for (final chunk in stream) {
        // Check if this chunk contains tool_call JSON
        final parsed = _tryParseToolCall(chunk);
        if (parsed != null) {
          await _handleToolCall(parsed, buffer, msg);
        } else {
          buffer.write(chunk);
          _updateMessage(msg, content: buffer.toString(), source: MessageSource.cloud);
        }
      }

      _updateMessage(msg,
          content: buffer.toString(),
          status: MessageStatus.complete,
          source: MessageSource.cloud);
    } on ZaiException catch (e) {
      final errorMsg = _formatApiError(e);
      _updateMessage(msg,
          content: buffer.isEmpty ? errorMsg : buffer.toString(),
          status: buffer.isEmpty ? MessageStatus.error : MessageStatus.complete,
          errorMessage: errorMsg);
    } catch (e) {
      final errorMsg = 'Cloud API error: ${e.toString()}';
      _updateMessage(msg,
          content: buffer.isEmpty ? errorMsg : buffer.toString(),
          status: buffer.isEmpty ? MessageStatus.error : MessageStatus.complete,
          errorMessage: errorMsg);
    }
  }

  /// Try to parse a tool_call from a stream chunk.
  /// Returns null if the chunk is regular text content.
  Map<String, dynamic>? _tryParseToolCall(String chunk) {
    // Only attempt parsing on chunks that look like tool_call JSON
    if (!chunk.contains('"type"') || !chunk.contains('"tool_call"')) {
      return null;
    }
    try {
      final parsed = jsonDecode(chunk) as Map<String, dynamic>;
      if (parsed['type'] == 'tool_call') {
        return parsed;
      }
    } catch (_) {
      // Not valid JSON - treat as regular text
    }
    return null;
  }

  /// Handle a tool call from the API.
  Future<void> _handleToolCall(
    Map<String, dynamic> toolCall,
    StringBuffer buffer,
    ChatMessage msg,
  ) async {
    final toolName = toolCall['name'] as String? ?? 'unknown';
    String argsStr = toolCall['arguments'] as String? ?? '{}';

    // Parse arguments safely
    Map<String, dynamic> args;
    try {
      args = jsonDecode(argsStr) as Map<String, dynamic>;
    } catch (_) {
      args = {};
    }

    // Show tool usage indicator
    buffer.write('\n\n🔍 Memanggil tool: *$toolName*...\n');
    _updateMessage(msg, content: buffer.toString(), source: MessageSource.cloud);

    try {
      final result = await _mcpService!.executeTool(toolName, args);
      if (result.success) {
        buffer.write('✅ $toolName berhasil.\n\n');
      } else {
        buffer.write('❌ $toolName gagal: ${result.result}\n\n');
      }
    } catch (e) {
      buffer.write('❌ Error tool: $e\n\n');
    }

    _updateMessage(msg, content: buffer.toString(), source: MessageSource.cloud);
  }

  /// Format API error for user display.
  String _formatApiError(ZaiException e) {
    if (e.statusCode == 401) {
      return 'API key tidak valid. Periksa API key di Settings.';
    } else if (e.statusCode == 429) {
      return 'Rate limit tercapai. Coba lagi beberapa saat.';
    } else if (e.statusCode == 500) {
      return 'Server API sedang bermasalah. Coba lagi nanti.';
    } else if (e.statusCode != null) {
      return 'API error (${e.statusCode}). Coba lagi.';
    }
    return 'Gagal terhubung ke API: ${e.message}';
  }

  /// Build conversation history for API context.
  /// Includes all completed messages plus the current prompt.
  List<Map<String, String>> _buildConversationHistory(String currentPrompt) {
    final history = <Map<String, String>>[];

    // Add completed past messages (not the current user message which was just added)
    for (final m in _messages) {
      if (m.status == MessageStatus.complete &&
          m.content.isNotEmpty &&
          m.id != _messages.last.id) {
        history.add({
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.content,
        });
      }
    }

    return history;
  }

  void _updateMessage(ChatMessage msg,
      {String? content,
      MessageStatus? status,
      String? errorMessage,
      MessageSource? source}) {
    final index = _messages.indexWhere((m) => m.id == msg.id);
    if (index != -1) {
      _messages[index] = msg.copyWith(
        content: content,
        status: status,
        errorMessage: errorMessage,
        source: source,
      );
      notifyListeners();
    }
  }

  void stopGeneration() {
    LocalInferenceService.instance.stopGeneration();
    _isGenerating = false;
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }

  Future<void> regenerateLastMessage() async {
    if (_messages.length < 2) return;

    if (!_messages.last.isUser) {
      _messages.removeLast();
    }

    final lastUserMsg = _messages.where((m) => m.isUser).lastOrNull;
    if (lastUserMsg != null) {
      _messages.remove(lastUserMsg);
      notifyListeners();
      await sendMessage(lastUserMsg.content);
    }
  }

  @override
  void dispose() {
    LocalInferenceService.instance.dispose();
    _zai?.dispose();
    super.dispose();
  }
}
