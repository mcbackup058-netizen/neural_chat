import 'package:uuid/uuid.dart';

enum MessageSource { local, cloud, system }
enum MessageStatus { sending, streaming, complete, error }

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final MessageSource source;
  final MessageStatus status;
  final DateTime timestamp;
  final String? modelId;
  final String? errorMessage;

  ChatMessage({
    String? id,
    required this.content,
    required this.isUser,
    this.source = MessageSource.local,
    this.status = MessageStatus.complete,
    DateTime? timestamp,
    this.modelId,
    this.errorMessage,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    MessageStatus? status,
    String? errorMessage,
    MessageSource? source,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      isUser: isUser,
      source: source ?? this.source,
      status: status ?? this.status,
      timestamp: timestamp,
      modelId: modelId,
      errorMessage: errorMessage,
    );
  }
}
