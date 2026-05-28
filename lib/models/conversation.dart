import 'chat_message.dart';

class Conversation {
  final String id;
  String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isPinned;

  Conversation({
    required this.id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPinned = false,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.where((m) => m.status == MessageStatus.complete || m.status == MessageStatus.error).map((m) => m.toJson()).toList(),
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'isPinned': isPinned,
  };

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final msgs = (json['messages'] as List?)
        ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList() ?? [];
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'New Chat',
      messages: msgs,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }

  Conversation copyWith({String? title, List<ChatMessage>? messages, bool? isPinned}) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
