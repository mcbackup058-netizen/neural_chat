import 'dart:async';
import 'dart:io';
import '../models/model_config.dart';

/// Local inference service for GGUF models.
/// Currently uses a simulated backend. To enable real GGUF inference:
/// 1. Install the `llama_cpp_dart` package
/// 2. Build or download llama.cpp native libraries for Android (armeabi-v7a, arm64-v8a)
/// 3. Place .so files in android/app/src/main/jniLibs/{abi}/libllama.dylib (or .so)
/// 4. Uncomment the llama_cpp_dart initialization code below
abstract class LocalInferenceService {
  static LocalInferenceService? _instance;
  static LocalInferenceService get instance =>
      _instance ??= _LocalInferenceServiceImpl();

  factory LocalInferenceService() => instance;

  Future<bool> loadModel(LocalModelConfig config);
  Future<void> unloadModel();
  Future<bool> isModelLoaded();
  Stream<String> generate(String prompt, {int maxTokens = 2048});
  void stopGeneration();
  void dispose();
}

class _LocalInferenceServiceImpl implements LocalInferenceService {
  bool _isLoaded = false;
  bool _isGenerating = false;
  StreamController<String>? _streamController;
  Timer? _simulationTimer;

  @override
  Future<bool> loadModel(LocalModelConfig config) async {
    // Check if GGUF file exists
    final file = File(config.filePath);
    if (!await file.exists()) {
      throw Exception('Model file not found: ${config.filePath}');
    }

    // Check file extension
    if (!config.filePath.toLowerCase().endsWith('.gguf')) {
      throw Exception(
          'Unsupported model format. Only .gguf files are supported.');
    }

    // Check file size
    final fileSize = await file.length();
    if (fileSize < 1024 * 1024) {
      throw Exception(
          'Model file too small. Please provide a valid GGUF model.');
    }

    // Simulate model loading (replace with real llama.cpp initialization)
    await Future.delayed(const Duration(seconds: 2));

    /*
    // === REAL LLAMA.CPP INTEGRATION ===
    // Uncomment below and add llama_cpp_dart dependency to pubspec.yaml:
    //
    // final llama = Llama.instance;
    // final params = LlamaParams(
    //   model: config.filePath,
    //   nCtx: config.contextSize,
    //   nGpuLayers: config.gpuLayers,
    // );
    // await llama.loadModel(params);
    */

    _isLoaded = true;
    return true;
  }

  @override
  Future<void> unloadModel() async {
    _isGenerating = false;
    _simulationTimer?.cancel();
    _streamController?.close();
    _isLoaded = false;

    /*
    // === REAL LLAMA.CPP INTEGRATION ===
    // final llama = Llama.instance;
    // await llama.dispose();
    */
  }

  @override
  Future<bool> isModelLoaded() async => _isLoaded;

  @override
  Stream<String> generate(String prompt, {int maxTokens = 2048}) async* {
    if (!_isLoaded) {
      throw Exception(
          'No model loaded. Please load a GGUF model first.');
    }

    _isGenerating = true;
    _streamController = StreamController<String>();

    /*
    // === REAL LLAMA.CPP INTEGRATION ===
    // final llama = Llama.instance;
    // llama.setPrompt(prompt);
    // await for (final token in llama.generate()) {
    //   if (!_isGenerating) break;
    //   yield token;
    // }
    */

    // Simulated streaming response for demonstration
    const simulatedResponse = 'Halo! Saya adalah model lokal yang berjalan di perangkat Anda. '
        'Saat ini, saya berjalan dalam mode simulasi.\n\n'
        'Untuk mengaktifkan inferensi GGUF yang sebenarnya, Anda perlu:\n'
        '1. Menginstall library llama.cpp native untuk Android\n'
        '2. Menempatkan file .so di folder jniLibs\n'
        '3. Menggunakan package llama_cpp_dart\n\n'
        'Fitur yang tersedia saat ini:\n'
        '- Manajemen file model GGUF\n'
        '- Konfigurasi parameter inferensi\n'
        '- Fallback ke GLM 5.1 Cloud API\n'
        '- MCP (Model Context Protocol) support\n\n';

    final words = simulatedResponse.split(' ');
    int tokenCount = 0;

    for (final word in words) {
      if (!_isGenerating || tokenCount >= maxTokens) break;
      yield word + ' ';
      tokenCount++;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _isGenerating = false;
    await _streamController?.close();
  }

  @override
  void stopGeneration() {
    _isGenerating = false;
    _simulationTimer?.cancel();
    _streamController?.close();
  }

  @override
  void dispose() {
    _isGenerating = false;
    _simulationTimer?.cancel();
    _streamController?.close();
  }
}
