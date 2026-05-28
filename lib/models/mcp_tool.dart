class McpTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final String category;

  McpTool({
    required this.name,
    required this.description,
    required this.parameters,
    this.category = 'general',
  });

  factory McpTool.fromJson(Map<String, dynamic> json) {
    return McpTool(
      name: json['name'] as String,
      description: json['description'] as String,
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      category: json['category'] as String? ?? 'general',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'parameters': parameters,
    'category': category,
  };
}

class McpToolResult {
  final String toolName;
  final bool success;
  final String result;
  final DateTime timestamp;

  McpToolResult({
    required this.toolName,
    required this.success,
    required this.result,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
