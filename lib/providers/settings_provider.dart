import 'package:flutter/foundation.dart';
import '../models/model_config.dart';
import '../services/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsService _settings;

  SettingsProvider(this._settings);

  // GLM API Settings
  String get glmApiKey => _settings.glmApiKey;
  String get glmApiUrl => _settings.glmApiUrl;
  bool get useCloudFallback => _settings.useCloudFallback;

  // Default inference parameters
  double get defaultTemperature => _settings.defaultTemperature;
  int get defaultContextSize => _settings.defaultContextSize;
  int get defaultMaxTokens => _settings.defaultMaxTokens;

  // Saved models
  List<LocalModelConfig> _models = [];
  List<LocalModelConfig> get models => List.unmodifiable(_models);

  Future<void> loadSettings() async {
    await _settings.init();
    _models = _settings.loadModels();
    notifyListeners();
  }

  // GLM API
  void setGlmApiKey(String key) {
    _settings.glmApiKey = key;
    notifyListeners();
  }

  void setGlmApiUrl(String url) {
    _settings.glmApiUrl = url;
    notifyListeners();
  }

  void setUseCloudFallback(bool value) {
    _settings.useCloudFallback = value;
    notifyListeners();
  }

  // Inference parameters
  void setDefaultTemperature(double value) {
    _settings.defaultTemperature = value;
    notifyListeners();
  }

  void setDefaultContextSize(int value) {
    _settings.defaultContextSize = value;
    notifyListeners();
  }

  void setDefaultMaxTokens(int value) {
    _settings.defaultMaxTokens = value;
    notifyListeners();
  }

  // Model management
  Future<void> addModel(LocalModelConfig model) async {
    _models.add(model);
    await _settings.saveModels(_models);
    notifyListeners();
  }

  Future<void> removeModel(String modelId) async {
    _models.removeWhere((m) => m.id == modelId);
    await _settings.saveModels(_models);
    notifyListeners();
  }

  Future<void> updateModel(LocalModelConfig model) async {
    final index = _models.indexWhere((m) => m.id == model.id);
    if (index != -1) {
      _models[index] = model;
      await _settings.saveModels(_models);
      notifyListeners();
    }
  }
}
