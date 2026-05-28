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
  static const _keySystemPrompt = 'system_prompt';
  static const _keyCloudModel = 'cloud_model';
  static const _keyThemeMode = 'theme_mode';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  // GLM API
  String get glmApiKey {
    if (!_isInitialized) return '60507e439e404929b1c2e4fa5adb0410.3qvVGIPpqUtIVEvE';
    return _prefs?.getString(_keyGlmApiKey) ?? '60507e439e404929b1c2e4fa5adb0410.3qvVGIPpqUtIVEvE';
  }
  set glmApiKey(String value) {
    _prefs?.setString(_keyGlmApiKey, value);
  }

  String get glmApiUrl {
    if (!_isInitialized) return 'https://open.bigmodel.cn/api/paas/v4';
    return _prefs?.getString(_keyGlmApiUrl) ?? 'https://open.bigmodel.cn/api/paas/v4';
  }
  set glmApiUrl(String value) {
    _prefs?.setString(_keyGlmApiUrl, value);
  }

  bool get useCloudFallback {
    if (!_isInitialized) return true;
    return _prefs?.getBool(_keyUseCloudFallback) ?? true;
  }
  set useCloudFallback(bool value) {
    _prefs?.setBool(_keyUseCloudFallback, value);
  }

  // Model Management
  String get activeModelId {
    if (!_isInitialized) return '';
    return _prefs?.getString(_keyActiveModelId) ?? '';
  }
  set activeModelId(String value) {
    _prefs?.setString(_keyActiveModelId, value);
  }

  double get defaultTemperature {
    if (!_isInitialized) return 0.7;
    return _prefs?.getDouble(_keyDefaultTemperature) ?? 0.7;
  }
  set defaultTemperature(double value) {
    _prefs?.setDouble(_keyDefaultTemperature, value);
  }

  int get defaultContextSize {
    if (!_isInitialized) return 4096;
    return _prefs?.getInt(_keyDefaultContextSize) ?? 4096;
  }
  set defaultContextSize(int value) {
    _prefs?.setInt(_keyDefaultContextSize, value);
  }

  int get defaultMaxTokens {
    if (!_isInitialized) return 4096;
    return _prefs?.getInt(_keyMaxTokens) ?? 4096;
  }
  set defaultMaxTokens(int value) {
    _prefs?.setInt(_keyMaxTokens, value);
  }

  // System prompt
  String get systemPrompt {
    if (!_isInitialized) return '';
    return _prefs?.getString(_keySystemPrompt) ?? '';
  }
  set systemPrompt(String value) {
    _prefs?.setString(_keySystemPrompt, value);
  }

  // Cloud model selection
  String get cloudModel {
    if (!_isInitialized) return 'glm-4-plus';
    return _prefs?.getString(_keyCloudModel) ?? 'glm-4-plus';
  }
  set cloudModel(String value) {
    _prefs?.setString(_keyCloudModel, value);
  }

  // Theme
  String get themeMode {
    if (!_isInitialized) return 'dark';
    return _prefs?.getString(_keyThemeMode) ?? 'dark';
  }
  set themeMode(String value) {
    _prefs?.setString(_keyThemeMode, value);
  }

  // Save/Load Models
  Future<void> saveModels(List<LocalModelConfig> models) async {
    final jsonList = models.map((m) => m.toJson()).toList();
    await _prefs?.setString(_keySavedModels, jsonEncode(jsonList));
  }

  List<LocalModelConfig> loadModels() {
    if (!_isInitialized) return [];
    final jsonStr = _prefs?.getString(_keySavedModels);
    if (jsonStr == null) return [];
    final jsonList = jsonDecode(jsonStr) as List;
    return jsonList
        .map((j) => LocalModelConfig.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
