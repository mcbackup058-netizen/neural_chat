import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';
import 'package:uuid/uuid.dart';

class ChatHistoryService {
  static const _keyConversations = 'chat_conversations';
  static const _keyActiveConversationId = 'active_conversation_id';
  static const _maxConversations = 50;

  SharedPreferences? _prefs;
  final List<Conversation> _conversations = [];
  String? _activeConversationId;

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  String? get activeConversationId => _activeConversationId;
  Conversation? get activeConversation {
    if (_activeConversationId == null) return null;
    try {
      return _conversations.firstWhere((c) => c.id == _activeConversationId);
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadConversations();
  }

  void _loadConversations() {
    final jsonStr = _prefs?.getString(_keyConversations);
    if (jsonStr == null) {
      _conversations.clear();
      return;
    }
    try {
      final jsonList = jsonDecode(jsonStr) as List;
      _conversations.clear();
      _conversations.addAll(
        jsonList
            .map((j) => Conversation.fromJson(j as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      debugPrint('Failed to load conversations: $e');
      _conversations.clear();
    }
    _activeConversationId = _prefs?.getString(_keyActiveConversationId);
  }

  Future<void> _saveConversations() async {
    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await _prefs?.setString(_keyConversations, jsonEncode(jsonList));
  }

  Future<void> _saveActiveId() async {
    await _prefs?.setString(_keyActiveConversationId, _activeConversationId ?? '');
  }

  Conversation createNewConversation({String? title}) {
    final conversation = Conversation(
      id: const Uuid().v4(),
      title: title ?? 'Chat Baru',
    );
    _conversations.insert(0, conversation);
    _activeConversationId = conversation.id;
    _trimOldConversations();
    _saveConversations();
    _saveActiveId();
    return conversation;
  }

  Future<void> addMessage(String conversationId, dynamic message) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    _conversations[index].messages.add(message);
    _conversations[index].updatedAt = DateTime.now();

    // Auto-title from first user message
    if (_conversations[index].title == 'Chat Baru' &&
        message.isUser &&
        message.content.isNotEmpty) {
      _conversations[index].title =
          message.content.length > 40
              ? '${message.content.substring(0, 40)}...'
              : message.content;
    }

    await _saveConversations();
  }

  Future<void> updateLastAssistantMessage(
    String conversationId,
    dynamic message,
  ) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    final msgs = _conversations[index].messages;
    if (msgs.isNotEmpty && !msgs.last.isUser) {
      msgs[msgs.length - 1] = message;
      await _saveConversations();
    }
  }

  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((c) => c.id == id);
    if (_activeConversationId == id) {
      _activeConversationId =
          _conversations.isNotEmpty ? _conversations.first.id : null;
    }
    await _saveConversations();
    await _saveActiveId();
  }

  Future<void> clearMessages(String conversationId) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    _conversations[index] = _conversations[index].copyWith(
      messages: [],
      title: 'Chat Baru',
    );
    await _saveConversations();
  }

  Future<void> setActiveConversation(String id) async {
    _activeConversationId = id;
    await _saveActiveId();
  }

  Future<void> togglePin(String id) async {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _conversations[index] = _conversations[index].copyWith(
      isPinned: !_conversations[index].isPinned,
    );
    // Re-sort: pinned first, then by updatedAt desc
    _conversations.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    await _saveConversations();
  }

  Future<void> renameConversation(String id, String newTitle) async {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _conversations[index] = _conversations[index].copyWith(title: newTitle);
    await _saveConversations();
  }

  String exportConversation(String id) {
    final conv = _conversations.firstWhere(
      (c) => c.id == id,
      orElse: () => throw Exception('Conversation not found'),
    );
    final buffer = StringBuffer();
    buffer.writeln('=== ${conv.title} ===');
    buffer.writeln('Created: ${conv.createdAt}');
    buffer.writeln('Messages: ${conv.messages.length}');
    buffer.writeln();
    for (final msg in conv.messages) {
      final role = msg.isUser ? 'You' : 'AI';
      final time = msg.timestamp.toString().substring(0, 19);
      buffer.writeln('[$time] $role:');
      buffer.writeln(msg.content);
      buffer.writeln();
    }
    return buffer.toString();
  }

  void _trimOldConversations() {
    if (_conversations.length > _maxConversations) {
      final unpinned = _conversations.where((c) => !c.isPinned).toList();
      unpinned.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      final toRemove = unpinned
          .take(unpinned.length - (_maxConversations - _conversations.where((c) => c.isPinned).length))
          .map((c) => c.id)
          .toSet();
      _conversations.removeWhere((c) => toRemove.contains(c.id));
    }
  }
}
