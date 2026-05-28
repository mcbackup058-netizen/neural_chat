import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/model_config.dart';

class SettingsService {
  static const _keyGlmApiKey = 'glm_api_key';
  static const _keyGlmApiUrl = 'glm_api_url';
  static const _keyUseCloudFallback = 'use_cloud_fallback';
  static const _keySavedModels = 'saved_models';
  static const _keyActiveModelId = 'active_model_id';
  static const _keyDefaultTemperature = 'default_temperature';
  static const _keyDefaultContextSize = 'default_context_size';
  static const _keyMaxTokens = 'default_max_tokens';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // GLM API
  String get glmApiKey => _prefs.getString(_keyGlmApiKey) ?? '60507e439e404929b1c2e4fa5adb0410.3qvVGIPpqUtIVEvE';
  set glmApiKey(String value) => _prefs.setString(_keyGlmApiKey, value);

  String get glmApiUrl =>
      _prefs.getString(_keyGlmApiUrl) ??
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  set glmApiUrl(String value) =>
      _prefs.setString(_keyGlmApiUrl, value);

  bool get useCloudFallback =>
      _prefs.getBool(_keyUseCloudFallback) ?? true;
  set useCloudFallback(bool value) =>
      _prefs.setBool(_keyUseCloudFallback, value);

  // Model Management
  String get activeModelId => _prefs.getString(_keyActiveModelId) ?? '';
  set activeModelId(String value) =>
      _prefs.setString(_keyActiveModelId, value);

  double get defaultTemperature =>
      _prefs.getDouble(_keyDefaultTemperature) ?? 0.7;
  set defaultTemperature(double value) =>
      _prefs.setDouble(_keyDefaultTemperature, value);

  int get defaultContextSize =>
      _prefs.getInt(_keyDefaultContextSize) ?? 4096;
  set defaultContextSize(int value) =>
      _prefs.setInt(_keyDefaultContextSize, value);

  int get defaultMaxTokens => _prefs.getInt(_keyMaxTokens) ?? 2048;
  set defaultMaxTokens(int value) =>
      _prefs.setInt(_keyMaxTokens, value);

  // Save/Load Models
  Future<void> saveModels(List<LocalModelConfig> models) async {
    final jsonList = models.map((m) => m.toJson()).toList();
    await _prefs.setString(_keySavedModels, jsonEncode(jsonList));
  }

  List<LocalModelConfig> loadModels() {
    final jsonStr = _prefs.getString(_keySavedModels);
    if (jsonStr == null) return [];
    final jsonList = jsonDecode(jsonStr) as List;
    return jsonList
        .map((j) => LocalModelConfig.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
