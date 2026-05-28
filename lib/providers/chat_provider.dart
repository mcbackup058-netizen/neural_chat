import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/model_config.dart';
import '../services/local_inference_service.dart';
import '../services/z_ai_web_dev_sdk.dart';
import '../services/mcp_service.dart';
import '../services/settings_service.dart';
import '../services/chat_history_service.dart';

enum ChatMode { local, cloud, auto }

class ChatProvider extends ChangeNotifier {
  final SettingsService _settings;
  final ChatHistoryService _history;
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
  String _currentConversationId = '';

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
  String get currentConversationId => _currentConversationId;

  ChatProvider(this._settings, this._history) {
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      if (_settings.glmApiKey.isNotEmpty) {
        _zai = await ZAI.create(
          apiKey: _settings.glmApiKey,
          baseUrl: _settings.glmApiUrl,
        );
        _mcpService = McpService(zai: _zai!);
        _mcpService!.setModel(_settings.cloudModel);
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

  void updateCloudModel(String model) {
    _mcpService?.setModel(model);
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

  /// Load messages from a conversation.
  void loadConversation(String conversationId) {
    final conv = _history.conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw Exception('Conversation not found'),
    );
    _currentConversationId = conversationId;
    _messages.clear();
    _messages.addAll(conv.messages);
    notifyListeners();
  }

  /// Start a new conversation.
  void newConversation() {
    final conv = _history.createNewConversation();
    _currentConversationId = conv.id;
    _messages.clear();
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // Ensure we have a conversation
    if (_currentConversationId.isEmpty) {
      newConversation();
    }

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
    await _history.addMessage(_currentConversationId, userMsg);
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

    final startTime = DateTime.now();

    try {
      final useLocal = _shouldUseLocal();

      if (useLocal && hasLocalModel) {
        await _generateLocal(content, assistantMsg, startTime);
      } else if (isCloudReady) {
        await _generateCloud(content, assistantMsg, startTime);
      } else if (hasApiKey && !isCloudReady) {
        await reinitializeServices();
        if (isCloudReady) {
          await _generateCloud(content, assistantMsg, startTime);
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

  Future<void> _generateLocal(String prompt, ChatMessage msg, DateTime startTime) async {
    final service = LocalInferenceService.instance;
    final buffer = StringBuffer();

    try {
      await for (final token in service.generate(prompt,
          maxTokens: _activeModel?.maxTokens ?? 2048)) {
        buffer.write(token);
        _updateMessage(msg, content: buffer.toString());
      }
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      _updateMessage(msg,
          content: buffer.toString(),
          status: MessageStatus.complete,
          source: MessageSource.local,
          responseTimeMs: responseTime);
      await _history.updateLastAssistantMessage(_currentConversationId, msg.copyWith(
        content: buffer.toString(),
        status: MessageStatus.complete,
        source: MessageSource.local,
        responseTimeMs: responseTime,
      ));
    } catch (e) {
      if (_settings.useCloudFallback && isCloudReady) {
        buffer.clear();
        _updateMessage(msg, content: '', status: MessageStatus.streaming);
        await _generateCloud(prompt, msg, startTime);
      } else {
        rethrow;
      }
    }
  }

  /// Generate via z-ai-web-dev-sdk cloud (GLM + MCP).
  Future<void> _generateCloud(String prompt, ChatMessage msg, DateTime startTime) async {
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
        customSystemPrompt: _settings.systemPrompt.isEmpty ? null : _settings.systemPrompt,
      );

      await for (final chunk in stream) {
        final parsed = _tryParseToolCall(chunk);
        if (parsed != null) {
          await _handleToolCall(parsed, buffer, msg);
        } else {
          buffer.write(chunk);
          _updateMessage(msg, content: buffer.toString(), source: MessageSource.cloud);
        }
      }

      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      _updateMessage(msg,
          content: buffer.toString(),
          status: MessageStatus.complete,
          source: MessageSource.cloud,
          responseTimeMs: responseTime);
      await _history.updateLastAssistantMessage(_currentConversationId, msg.copyWith(
        content: buffer.toString(),
        status: MessageStatus.complete,
        source: MessageSource.cloud,
        responseTimeMs: responseTime,
      ));
    } on ZaiException catch (e) {
      final errorMsg = _formatApiError(e);
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      _updateMessage(msg,
          content: buffer.isEmpty ? errorMsg : buffer.toString(),
          status: buffer.isEmpty ? MessageStatus.error : MessageStatus.complete,
          errorMessage: buffer.isEmpty ? errorMsg : null,
          responseTimeMs: responseTime);
    } catch (e) {
      final errorMsg = 'Cloud API error: ${e.toString()}';
      _updateMessage(msg,
          content: buffer.isEmpty ? errorMsg : buffer.toString(),
          status: buffer.isEmpty ? MessageStatus.error : MessageStatus.complete,
          errorMessage: errorMsg);
    }
  }

  /// Try to parse a tool_call from a stream chunk.
  Map<String, dynamic>? _tryParseToolCall(String chunk) {
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
  List<Map<String, String>> _buildConversationHistory(String currentPrompt) {
    final history = <Map<String, String>>[];

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
      MessageSource? source,
      int? responseTimeMs,
      int? promptTokens,
      int? completionTokens}) {
    final index = _messages.indexWhere((m) => m.id == msg.id);
    if (index != -1) {
      _messages[index] = msg.copyWith(
        content: content,
        status: status,
        errorMessage: errorMessage,
        source: source,
        responseTimeMs: responseTimeMs,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
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
    if (_currentConversationId.isNotEmpty) {
      _history.clearMessages(_currentConversationId);
    }
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

  /// Delete a conversation from history.
  Future<void> deleteConversation(String id) async {
    await _history.deleteConversation(id);
    if (_currentConversationId == id) {
      if (_history.conversations.isNotEmpty) {
        loadConversation(_history.conversations.first.id);
      } else {
        newConversation();
      }
    }
    notifyListeners();
  }

  /// Get chat history service for UI access.
  ChatHistoryService get historyService => _history;

  @override
  void dispose() {
    LocalInferenceService.instance.dispose();
    _zai?.dispose();
    super.dispose();
  }
}
