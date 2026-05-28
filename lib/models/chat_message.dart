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
  final int responseTimeMs;
  final int? promptTokens;
  final int? completionTokens;

  ChatMessage({
    String? id,
    required this.content,
    required this.isUser,
    this.source = MessageSource.local,
    this.status = MessageStatus.complete,
    DateTime? timestamp,
    this.modelId,
    this.errorMessage,
    this.responseTimeMs = 0,
    this.promptTokens,
    this.completionTokens,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    MessageStatus? status,
    String? errorMessage,
    MessageSource? source,
    int? responseTimeMs,
    int? promptTokens,
    int? completionTokens,
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
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'isUser': isUser,
    'source': source.index,
    'status': status.index,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'modelId': modelId,
    'errorMessage': errorMessage,
    'responseTimeMs': responseTimeMs,
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      source: MessageSource.values[json['source'] as int? ?? 0],
      status: MessageStatus.values[json['status'] as int? ?? 2],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      modelId: json['modelId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      responseTimeMs: json['responseTimeMs'] as int? ?? 0,
      promptTokens: json['promptTokens'] as int?,
      completionTokens: json['completionTokens'] as int?,
    );
  }
}
