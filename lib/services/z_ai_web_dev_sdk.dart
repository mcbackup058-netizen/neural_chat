import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// Dart port of z-ai-web-dev-sdk for Zhipu GLM API.
class ZAI {
  final String apiKey;
  late final String _keyId;
  late final String _keySecret;
  final String baseUrl;
  final http.Client _client;

  late final ChatCompletions chatCompletions;
  late final Functions functions;
  late final Images images;

  ZAI._({
    required this.apiKey,
    this.baseUrl = 'https://open.bigmodel.cn/api/paas/v4',
    http.Client? client,
  })  : _client = client ?? http.Client() {
    final parts = apiKey.split('.');
    _keyId = parts[0];
    _keySecret = parts.length > 1 ? parts[1] : '';
    chatCompletions = ChatCompletions._(this);
    functions = Functions._(this);
    images = Images._(this);
  }

  static Future<ZAI> create({
    required String apiKey,
    String baseUrl = 'https://open.bigmodel.cn/api/paas/v4',
  }) async {
    return ZAI._(apiKey: apiKey, baseUrl: baseUrl);
  }

  /// Generate JWT token from API key (id.secret format).
  Future<String> _generateToken() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = now + 3600;

    final header = _base64UrlNoPadding(utf8.encode(jsonEncode({
      'alg': 'HS256',
      'sign_type': 'SIGN',
    })));

    final payload = _base64UrlNoPadding(utf8.encode(jsonEncode({
      'api_key': _keyId,
      'exp': exp,
      'timestamp': now,
    })));

    final message = '$header.$payload';
    final key = utf8.encode(_keySecret);
    final hmac = Hmac(sha256, key);
    final sigBytes = hmac.convert(utf8.encode(message)).bytes;
    final signature = _base64UrlNoPadding(sigBytes);

    return '$message.$signature';
  }

  Future<Map<String, String>> get _headers async {
    final token = await _generateToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  String _base64UrlNoPadding(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  void dispose() {
    _client.close();
  }
}

/// Chat completions module.
class ChatCompletions {
  final ZAI _zai;
  ChatCompletions._(this._zai);

  /// Non-streaming chat completion.
  Future<ChatCompletionResponse> create({
    required List<Map<String, String>> messages,
    String model = 'glm-4-plus',
    double temperature = 0.7,
    int maxTokens = 2048,
    double topP = 0.7,
    List<Map<String, dynamic>>? tools,
    String? toolChoice,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'top_p': topP,
      'stream': false,
    };

    if (tools != null && tools.isNotEmpty) body['tools'] = tools;
    if (toolChoice != null) body['tool_choice'] = toolChoice;

    final headers = await _zai._headers;
    final response = await _zai._client
        .post(
          Uri.parse('${_zai.baseUrl}/chat/completions'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw ZaiException(
        'Chat error ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ChatCompletionResponse.fromJson(json);
  }

  /// Streaming chat completion - yields tokens as they arrive via SSE.
  /// CRITICAL FIX: Properly accumulates tool call arguments across chunks.
  Stream<String> createStream({
    required List<Map<String, String>> messages,
    String model = 'glm-4-plus',
    double temperature = 0.7,
    int maxTokens = 2048,
    double topP = 0.7,
    List<Map<String, dynamic>>? tools,
  }) async* {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'top_p': topP,
      'stream': true,
    };

    if (tools != null && tools.isNotEmpty) body['tools'] = tools;

    final headers = await _zai._headers;
    final request = http.Request(
      'POST',
      Uri.parse('${_zai.baseUrl}/chat/completions'),
    );
    request.headers.addAll(headers);
    request.body = jsonEncode(body);

    final response = await _zai._client.send(request).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw ZaiException('Connection timeout');
          },
        );

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString().timeout(
            const Duration(seconds: 10),
            onTimeout: () => '{"error":"timeout reading error response"}',
          );
      throw ZaiException(
        'Stream error ${response.statusCode}: $errorBody',
        statusCode: response.statusCode,
        body: errorBody,
      );
    }

    // CRITICAL: Accumulate tool call data across multiple SSE chunks
    final Map<int, _ToolCallAccumulator> toolCallAccumulators = {};

    String buffer = '';
    await for (final chunk
        in response.stream.transform(utf8.decoder).timeout(const Duration(minutes: 5))) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;

        final data = trimmed.substring(6);
        if (data == '[DONE]') {
          // Flush any remaining accumulated tool calls
          for (final entry in toolCallAccumulators.entries) {
            final acc = entry.value;
            if (acc.name.isNotEmpty && acc.arguments.isNotEmpty) {
              yield jsonEncode({
                'type': 'tool_call',
                'id': acc.id,
                'name': acc.name,
                'arguments': acc.arguments,
              });
            }
          }
          toolCallAccumulators.clear();
          return;
        }

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;

          final delta = choices[0]['delta'] as Map<String, dynamic>?;
          if (delta == null) continue;

          // Handle text content
          if (delta['content'] != null) {
            final content = delta['content'] as String;
            if (content.isNotEmpty) {
              yield content;
            }
          }

          // Handle tool calls - CRITICAL FIX: Accumulate across chunks
          if (delta['tool_calls'] != null) {
            final toolCalls = delta['tool_calls'] as List;
            for (final tc in toolCalls) {
              final index = tc['index'] as int? ?? 0;
              final fn = tc['function'] as Map<String, dynamic>?;

              if (!toolCallAccumulators.containsKey(index)) {
                toolCallAccumulators[index] = _ToolCallAccumulator();
              }
              final acc = toolCallAccumulators[index]!;

              if (tc['id'] != null) acc.id = tc['id'] as String;
              if (fn != null) {
                if (fn['name'] != null) acc.name = fn['name'] as String;
                if (fn['arguments'] != null) acc.arguments += fn['arguments'] as String;
              }
            }
          }

          // Check if this is the last chunk (finish_reason: 'tool_calls' or 'stop')
          final finishReason = choices[0]['finish_reason'] as String?;
          if (finishReason != null) {
            if (finishReason == 'tool_calls' || finishReason == 'stop') {
              // Flush accumulated tool calls
              for (final entry in toolCallAccumulators.entries) {
                final acc = entry.value;
                if (acc.name.isNotEmpty && acc.arguments.isNotEmpty) {
                  yield jsonEncode({
                    'type': 'tool_call',
                    'id': acc.id,
                    'name': acc.name,
                    'arguments': acc.arguments,
                  });
                }
              }
              toolCallAccumulators.clear();
            }
          }
        } catch (e) {
          debugPrint('SSE parse error: $e');
        }
      }
    }
  }
}

/// Helper class to accumulate tool call data across multiple SSE chunks.
class _ToolCallAccumulator {
  String id = '';
  String name = '';
  String arguments = '';
}

/// Functions module.
class Functions {
  final ZAI _zai;
  Functions._(this._zai);

  Future<Map<String, dynamic>> invoke(
    String name,
    Map<String, dynamic> params,
  ) async {
    try {
      final headers = await _zai._headers;
      final response = await _zai._client
          .post(
            Uri.parse('${_zai.baseUrl}/functions/invoke'),
            headers: headers,
            body: jsonEncode({
              'name': name,
              'parameters': params,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Functions.invoke failed: $e');
    }

    // Fallback to chat completions
    return await _invokeViaChat(name, params);
  }

  Future<Map<String, dynamic>> _invokeViaChat(
    String name,
    Map<String, dynamic> params,
  ) async {
    final response = await _zai.chatCompletions.create(
      messages: [
        {'role': 'system', 'content': 'Execute the function and return JSON result.'},
        {'role': 'user', 'content': 'Function: $name\nParams: ${jsonEncode(params)}'},
      ],
      model: 'glm-4-flash',
      maxTokens: 1024,
    );

    return {
      'function': name,
      'parameters': params,
      'result': response.content,
      'success': true,
    };
  }
}

/// Images module.
class Images {
  final ZAI _zai;
  Images._(this._zai);

  Future<ImageGenerationResponse> create({
    required String prompt,
    String model = 'cogview-3-plus',
    String size = '1024x1024',
  }) async {
    final headers = await _zai._headers;
    final response = await _zai._client
        .post(
          Uri.parse('${_zai.baseUrl}/images/generations'),
          headers: headers,
          body: jsonEncode({'model': model, 'prompt': prompt, 'size': size}),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw ZaiException(
        'Image generation error ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ImageGenerationResponse.fromJson(json);
  }
}

/// Response models
class ChatCompletionResponse {
  final String id;
  final String model;
  final String content;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final String finishReason;
  final List<ToolCall>? toolCalls;

  ChatCompletionResponse({
    required this.id,
    required this.model,
    required this.content,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.finishReason,
    this.toolCalls,
  });

  factory ChatCompletionResponse.fromJson(Map<String, dynamic> json) {
    final usage = json['usage'] as Map<String, dynamic>? ?? {};
    final choices = json['choices'] as List?;
    final firstChoice = choices != null && choices.isNotEmpty
        ? choices[0] as Map<String, dynamic>
        : {};
    final message = firstChoice['message'] as Map<String, dynamic>? ?? {};

    List<ToolCall>? toolCalls;
    if (message['tool_calls'] != null) {
      toolCalls = (message['tool_calls'] as List)
          .map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
          .toList();
    }

    return ChatCompletionResponse(
      id: json['id'] as String? ?? '',
      model: json['model'] as String? ?? '',
      content: message['content'] as String? ?? '',
      promptTokens: usage['prompt_tokens'] as int? ?? 0,
      completionTokens: usage['completion_tokens'] as int? ?? 0,
      totalTokens: usage['total_tokens'] as int? ?? 0,
      finishReason: firstChoice['finish_reason'] as String? ?? 'stop',
      toolCalls: toolCalls,
    );
  }
}

class ToolCall {
  final String id;
  final String type;
  final FunctionCall function;

  ToolCall({required this.id, required this.type, required this.function});

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'function',
      function: FunctionCall.fromJson(
        json['function'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class FunctionCall {
  final String name;
  final String arguments;

  FunctionCall({required this.name, required this.arguments});

  factory FunctionCall.fromJson(Map<String, dynamic> json) {
    return FunctionCall(
      name: json['name'] as String? ?? '',
      arguments: json['arguments'] as String? ?? '{}',
    );
  }

  Map<String, dynamic> get parsedArguments {
    try {
      return jsonDecode(arguments) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

class ImageGenerationResponse {
  final int created;
  final List<String> imageData;

  ImageGenerationResponse({required this.created, required this.imageData});

  factory ImageGenerationResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    return ImageGenerationResponse(
      created: json['created'] as int? ?? 0,
      imageData: dataList
          .map((d) =>
              d['b64_image'] as String? ?? d['url'] as String? ?? '')
          .toList(),
    );
  }
}

/// ZAI SDK exception.
class ZaiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  ZaiException(this.message, {this.statusCode, this.body});

  @override
  String toString() =>
      'ZaiException: $message${statusCode != null ? ' (${statusCode})' : ''}';
}
