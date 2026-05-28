import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'services/settings_service.dart';
import 'screens/chat_screen.dart';

class NeuralChatApp extends StatelessWidget {
  const NeuralChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = SettingsService();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(settingsService)..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(settingsService),
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
