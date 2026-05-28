import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'services/settings_service.dart';
import 'screens/chat_screen.dart';

/// Global settings service instance shared across the app.
final SettingsService _settingsService = SettingsService();

class NeuralChatApp extends StatefulWidget {
  const NeuralChatApp({super.key});

  @override
  State<NeuralChatApp> createState() => _NeuralChatAppState();
}

class _NeuralChatAppState extends State<NeuralChatApp> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize SharedPreferences BEFORE anything else
    await _settingsService.init();
    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(_settingsService)..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(_settingsService),
        ),
      ],
      child: MaterialApp(
        title: 'NeuralChat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        home: const ChatScreen(),
      ),
    );
  }
}
