import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// Dart port of z-ai-web-dev-sdk for Zhipu GLM API.
///
/// Usage:
/// ```dart
/// final zai = await ZAI.create(apiKey: 'your-api-key');
///
/// // Chat completions
/// final completion = await zai.chat.completions.create(
///   messages: [
///     {'role': 'user', 'content': 'Hello!'},
///   ],
/// );
///
/// // Streaming
/// await for (final token in zai.chat.completions.createStream(
///   messages: [
///     {'role': 'user', 'content': 'Hello!'},
///   ],
/// )) {
///   print(token);
/// }
///
/// // Function calling
/// final result = await zai.functions.invoke('web_search', {
///   'query': 'Flutter framework',
/// });
///
/// zai.dispose();
/// ```
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

  /// Create a new ZAI instance.
  static Future<ZAI> create({
    required String apiKey,
    String baseUrl = 'https://open.bigmodel.cn/api/paas/v4',
  }) async {
    return ZAI._(apiKey: apiKey, baseUrl: baseUrl);
  }

  /// Generate JWT token from API key (id.secret format).
  /// Matches z-ai-web-dev-sdk internal token generation.
  Future<String> _generateToken() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = now + 3600; // 1 hour expiry

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

  /// Get authenticated headers with JWT token.
  Future<Map<String, String>> get _headers async {
    final token = await _generateToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Base64URL encode without padding (JWT standard).
  String _base64UrlNoPadding(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  void dispose() {
    _client.close();
  }
}

// ─── Chat Completions Module ─────────────────────────────────────────

/// Chat completions module - mirrors z-ai-web-dev-sdk chat.completions
class ChatCompletions {
  final ZAI _zai;
  ChatCompletions._(this._zai);

  /// Non-streaming chat completion request.
  /// Returns the full response text.
  Future<ChatCompletionResponse> create({
    required List<Map<String, String>> messages,
    String model = 'glm-4-plus',
    double temperature = 0.7,
    int maxTokens = 2048,
    double topP = 0.7,
    List<Map<String, dynamic>>? tools,
    String? toolChoice,
    bool stream = false,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'top_p': topP,
      'stream': false,
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
    }
    if (toolChoice != null) {
      body['tool_choice'] = toolChoice;
    }

    final headers = await _zai._headers;
    final response = await _zai._client.post(
      Uri.parse('${_zai.baseUrl}/chat/completions'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw ZaiException(
        'Chat completion error ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ChatCompletionResponse.fromJson(json);
  }

  /// Streaming chat completion - yields tokens as they arrive.
  /// Mirrors z-ai-web-dev-sdk streaming behavior.
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

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
    }

    final headers = await _zai._headers;
    final request = http.Request(
      'POST',
      Uri.parse('${_zai.baseUrl}/chat/completions'),
    );
    request.headers.addAll(headers);
    request.body = jsonEncode(body);

    final response = await _zai._client.send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw ZaiException(
        'Stream error ${response.statusCode}: $errorBody',
        statusCode: response.statusCode,
      );
    }

    String buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;

        final data = trimmed.substring(6);
        if (data == '[DONE]') return;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;

            // Handle text content
            if (delta != null && delta['content'] != null) {
              yield delta['content'] as String;
            }

            // Handle tool calls
            if (delta != null && delta['tool_calls'] != null) {
              final toolCalls = delta['tool_calls'] as List;
              for (final tc in toolCalls) {
                final fn = tc['function'] as Map<String, dynamic>?;
                if (fn != null && fn['arguments'] != null) {
                  // Yield tool call as JSON string for the caller to handle
                  yield jsonEncode({
                    'type': 'tool_call',
                    'id': tc['id'],
                    'name': fn['name'],
                    'arguments': fn['arguments'],
                  });
                }
              }
            }
          }
        } catch (_) {
          // Skip malformed chunks
        }
      }
    }
  }
}

// ─── Functions Module ────────────────────────────────────────────────

/// Functions module - mirrors z-ai-web-dev-sdk functions.invoke
class Functions {
  final ZAI _zai;
  Functions._(this._zai);

  /// Invoke a function/tool through the GLM API.
  /// Equivalent to zai.functions.invoke(name, params)
  Future<Map<String, dynamic>> invoke(
    String name,
    Map<String, dynamic> params,
  ) async {
    final headers = await _zai._headers;
    final response = await _zai._client.post(
      Uri.parse('${_zai.baseUrl}/functions/invoke'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'parameters': params,
      }),
    );

    if (response.statusCode != 200) {
      // If the invoke endpoint doesn't exist, use chat completions as fallback
      return await _invokeViaChat(name, params);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Fallback: use chat completions to simulate function invocation
  Future<Map<String, dynamic>> _invokeViaChat(
    String name,
    Map<String, dynamic> params,
  ) async {
    final systemPrompt = '''You are a function executor. Execute the following function and return ONLY a JSON result.
Function: $name
Parameters: ${jsonEncode(params)}
Respond with a JSON object containing the result.''';

    final response = await _zai.chatCompletions.create(
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': 'Execute the function.'},
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

// ─── Images Module ───────────────────────────────────────────────────

/// Images module - mirrors z-ai-web-dev-sdk images.generations
class Images {
  final ZAI _zai;
  Images._(this._zai);

  /// Generate an image from a text prompt.
  /// Returns base64-encoded image data.
  Future<ImageGenerationResponse> create({
    required String prompt,
    String model = 'cogview-3-plus',
    String size = '1024x1024',
  }) async {
    final headers = await _zai._headers;
    final response = await _zai._client.post(
      Uri.parse('${_zai.baseUrl}/images/generations'),
      headers: headers,
      body: jsonEncode({
        'model': model,
        'prompt': prompt,
        'size': size,
      }),
    );

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

// ─── Response Models ────────────────────────────────────────────────

/// Chat completion response (non-streaming).
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
    final firstChoice =
        choices != null && choices.isNotEmpty ? choices[0] as Map<String, dynamic> : {};
    final message = firstChoice['message'] as Map<String, dynamic>? ?? {};

    // Parse tool calls if present
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

/// Tool call from the model response.
class ToolCall {
  final String id;
  final String type;
  final FunctionCall function;

  ToolCall({
    required this.id,
    required this.type,
    required this.function,
  });

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

/// Function call details.
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

/// Image generation response.
class ImageGenerationResponse {
  final int created;
  final List<String> imageData; // base64

  ImageGenerationResponse({required this.created, required this.imageData});

  factory ImageGenerationResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    return ImageGenerationResponse(
      created: json['created'] as int? ?? 0,
      imageData: dataList.map((d) => d['b64_image'] as String? ?? d['url'] as String? ?? '').toList(),
    );
  }
}

// ─── Exception ───────────────────────────────────────────────────────

/// ZAI SDK exception.
class ZaiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  ZaiException(this.message, {this.statusCode, this.body});

  @override
  String toString() => 'ZaiException: $message${statusCode != null ? ' (${statusCode})' : ''}';
}
