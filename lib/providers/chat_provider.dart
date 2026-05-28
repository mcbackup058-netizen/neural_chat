import 'dart:async';
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

  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  ChatMode _chatMode = ChatMode.auto;
  String? _activeModelId;
  LocalModelConfig? _activeModel;
  String _lastError = '';

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  ChatMode get chatMode => _chatMode;
  String? get activeModelId => _activeModelId;
  LocalModelConfig? get activeModel => _activeModel;
  String get lastError => _lastError;
  bool get hasLocalModel => _activeModel != null && _activeModel!.isLoaded;
  bool get hasApiKey => _settings.glmApiKey.isNotEmpty;
  ZAI? get zai => _zai;

  ChatProvider(this._settings) {
    _initServices();
  }

  Future<void> _initServices() async {
    if (_settings.glmApiKey.isNotEmpty) {
      _zai = await ZAI.create(
        apiKey: _settings.glmApiKey,
      );
      _mcpService = McpService(zai: _zai!);
    }
  }

  void updateApiKey(String apiKey) {
    _settings.glmApiKey = apiKey;
    _zai?.dispose();
    _zai = null;
    _mcpService = null;
    _initServices();
    notifyListeners();
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
      _lastError = 'Failed to load model: $e';
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
      final useLocal = _shouldUseLocal(content);

      if (useLocal && hasLocalModel) {
        await _generateLocal(content, assistantMsg);
      } else if (hasApiKey) {
        await _generateCloud(content, assistantMsg);
      } else {
        final errorMsg = hasLocalModel
            ? 'Local model is available but encountered an error. No API key configured for cloud fallback.'
            : 'No model loaded and no API key configured. Please load a GGUF model or set your API key in settings.';
        _updateMessage(assistantMsg,
            content: errorMsg,
            status: MessageStatus.error,
            errorMessage: errorMsg);
      }
    } catch (e) {
      _updateMessage(assistantMsg,
          content: 'Error: $e',
          status: MessageStatus.error,
          errorMessage: e.toString());
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  bool _shouldUseLocal(String content) {
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
      if (_settings.useCloudFallback && hasApiKey) {
        buffer.clear();
        await _generateCloud(prompt, msg);
      } else {
        rethrow;
      }
    }
  }

  /// Generate via z-ai-web-dev-sdk cloud (GLM 5.1 + MCP).
  Future<void> _generateCloud(String prompt, ChatMessage msg) async {
    if (_zai == null || _mcpService == null) {
      throw Exception(
          'z-ai-web-dev-sdk not configured. Please set your API key in settings.');
    }

    final history = _buildConversationHistory();
    final buffer = StringBuffer();

    try {
      // Use z-ai-web-dev-sdk streaming via MCP service
      await for (final token in _mcpService!.chatWithMcp(
        messages: history,
        temperature: _settings.defaultTemperature,
        maxTokens: _settings.defaultMaxTokens,
      )) {
        buffer.write(token);
        _updateMessage(msg, content: buffer.toString());
      }
      _updateMessage(msg,
          content: buffer.toString(),
          status: MessageStatus.complete,
          source: MessageSource.cloud);
    } catch (e) {
      _updateMessage(msg,
          content: buffer.isEmpty ? 'Cloud API error: $e' : buffer.toString(),
          status: buffer.isEmpty ? MessageStatus.error : MessageStatus.complete,
          errorMessage: e.toString());
    }
  }

  List<Map<String, String>> _buildConversationHistory() {
    return _messages
        .where((m) => m.status != MessageStatus.error && m.content.isNotEmpty)
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();
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
