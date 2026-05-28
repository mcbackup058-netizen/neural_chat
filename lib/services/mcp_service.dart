import 'dart:convert';
import 'z_ai_web_dev_sdk.dart';
import '../models/mcp_tool.dart';

/// MCP (Model Context Protocol) Service
class McpService {
  final ZAI _zai;
  String _model = 'glm-4-plus';

  McpService({required ZAI zai}) : _zai = zai;

  void setModel(String model) {
    _model = model;
  }

  String get model => _model;

  /// Get available MCP tools in z-ai-web-dev-sdk function-calling format.
  List<Map<String, dynamic>> getToolDefinitions() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'web_search',
          'description':
              'Search the web for current information, news, and facts. '
              'Use this when the user asks about recent events, current data, or '
              'information that may not be in the training data.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'The search query string',
              },
            },
            'required': ['query'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'code_execute',
          'description':
              'Execute Python code and return the result. '
              'Use this for mathematical calculations, data processing, '
              'or when the user needs precise computational results.',
          'parameters': {
            'type': 'object',
            'properties': {
              'code': {
                'type': 'string',
                'description': 'The Python code to execute',
              },
            },
            'required': ['code'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'image_analysis',
          'description':
              'Analyze an image and describe its contents. '
              'Use this when the user provides an image URL or asks about visual content.',
          'parameters': {
            'type': 'object',
            'properties': {
              'image_url': {
                'type': 'string',
                'description': 'URL of the image to analyze',
              },
              'question': {
                'type': 'string',
                'description': 'Specific question about the image',
              },
            },
            'required': ['image_url'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'knowledge_search',
          'description':
              'Search academic and knowledge databases for scholarly '
              'information, research papers, and expert knowledge.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'The knowledge search query',
              },
              'domain': {
                'type': 'string',
                'enum': ['general', 'academic', 'technical', 'medical'],
                'description': 'The domain to search in',
              },
            },
            'required': ['query'],
          },
        },
      },
    ];
  }

  /// Execute an MCP tool call via z-ai-web-dev-sdk functions.invoke.
  Future<McpToolResult> executeTool(
      String toolName, Map<String, dynamic> args) async {
    try {
      final result = await _zai.functions.invoke(toolName, args);
      return McpToolResult(
        toolName: toolName,
        success: true,
        result: result['result'] as String? ?? jsonEncode(result),
      );
    } catch (e) {
      return McpToolResult(
        toolName: toolName,
        success: false,
        result: 'Tool execution error: $e',
      );
    }
  }

  /// Build system prompt with MCP context.
  String buildMcpSystemPrompt({String? customSystemPrompt}) {
    final basePrompt = customSystemPrompt?.isNotEmpty == true
        ? '$customSystemPrompt\n\n'
        : '';

    return '''${basePrompt}You are GLM, an advanced AI assistant integrated into NeuralChat app.

You are operating through the z-ai-web-dev-sdk interface as a cloud AI via the Model Context Protocol (MCP).

Available MCP Tools (via z-ai-web-dev-sdk functions.invoke):
- web_search: Search the web for current information
- code_execute: Execute Python code for calculations
- image_analysis: Analyze images and describe content
- knowledge_search: Search academic and knowledge databases

When the user's request requires any of these capabilities, use the appropriate tool.
Respond in the same language the user uses. Be helpful, accurate, and concise.''';
  }

  /// Stream chat through MCP using z-ai-web-dev-sdk chat.completions.createStream.
  Stream<String> chatWithMcp({
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
    String? customSystemPrompt,
  }) {
    final mcpMessages = [
      {'role': 'system', 'content': buildMcpSystemPrompt(customSystemPrompt: customSystemPrompt)},
      ...messages,
    ];

    return _zai.chatCompletions.createStream(
      messages: mcpMessages,
      model: _model,
      temperature: temperature,
      maxTokens: maxTokens,
      tools: getToolDefinitions(),
    );
  }

  /// Non-streaming version.
  Future<String> chatWithMcpSync({
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
    String? customSystemPrompt,
  }) async {
    final mcpMessages = [
      {'role': 'system', 'content': buildMcpSystemPrompt(customSystemPrompt: customSystemPrompt)},
      ...messages,
    ];

    final response = await _zai.chatCompletions.create(
      messages: mcpMessages,
      model: _model,
      temperature: temperature,
      maxTokens: maxTokens,
      tools: getToolDefinitions(),
    );

    return response.content;
  }
}
