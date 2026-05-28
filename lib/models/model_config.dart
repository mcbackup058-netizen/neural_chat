class LocalModelConfig {
  final String id;
  final String name;
  final String filePath;
  final int contextSize;
  final int maxTokens;
  final double temperature;
  final double topP;
  final int gpuLayers;
  final bool isLoaded;

  LocalModelConfig({
    required this.id,
    required this.name,
    required this.filePath,
    this.contextSize = 4096,
    this.maxTokens = 2048,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.gpuLayers = 0,
    this.isLoaded = false,
  });

  LocalModelConfig copyWith({
    String? name,
    int? contextSize,
    int? maxTokens,
    double? temperature,
    double? topP,
    int? gpuLayers,
    bool? isLoaded,
  }) {
    return LocalModelConfig(
      id: id,
      name: name ?? this.name,
      filePath: filePath,
      contextSize: contextSize ?? this.contextSize,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      gpuLayers: gpuLayers ?? this.gpuLayers,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'filePath': filePath,
    'contextSize': contextSize,
    'maxTokens': maxTokens,
    'temperature': temperature,
    'topP': topP,
    'gpuLayers': gpuLayers,
  };

  factory LocalModelConfig.fromJson(Map<String, dynamic> json) {
    return LocalModelConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      filePath: json['filePath'] as String,
      contextSize: json['contextSize'] as int? ?? 4096,
      maxTokens: json['maxTokens'] as int? ?? 2048,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      topP: (json['topP'] as num?)?.toDouble() ?? 0.9,
      gpuLayers: json['gpuLayers'] as int? ?? 0,
    );
  }
}
