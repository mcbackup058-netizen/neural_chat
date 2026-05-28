import 'dart:convert';
import 'z_ai_web_dev_sdk.dart';
import '../models/mcp_tool.dart';

/// MCP (Model Context Protocol) Service
/// Bridges between the local app and GLM 5.1 cloud API via z-ai-web-dev-sdk,
/// providing tools and context that enhance the AI's capabilities.
class McpService {
  final ZAI _zai;

  McpService({required ZAI zai}) : _zai = zai;

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

  /// Build system prompt with MCP context for z-ai-web-dev-sdk.
  String buildMcpSystemPrompt() {
    return '''You are GLM 5.1, an advanced AI assistant integrated into NeuralChat app.

You are operating through the z-ai-web-dev-sdk interface as a cloud fallback via the Model Context Protocol (MCP).
The user's primary model is a local GGUF model running on their device. You are called
when the local model cannot handle the request (too complex, needs web access, etc.).

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
  }) {
    final mcpMessages = [
      {'role': 'system', 'content': buildMcpSystemPrompt()},
      ...messages,
    ];

    return _zai.chatCompletions.createStream(
      messages: mcpMessages,
      model: 'glm-4-plus',
      temperature: temperature,
      maxTokens: maxTokens,
      tools: getToolDefinitions(),
    );
  }

  /// Non-streaming version using z-ai-web-dev-sdk chat.completions.create.
  Future<String> chatWithMcpSync({
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async {
    final mcpMessages = [
      {'role': 'system', 'content': buildMcpSystemPrompt()},
      ...messages,
    ];

    final response = await _zai.chatCompletions.create(
      messages: mcpMessages,
      model: 'glm-4-plus',
      temperature: temperature,
      maxTokens: maxTokens,
      tools: getToolDefinitions(),
    );

    return response.content;
  }
}
