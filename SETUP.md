# NeuralChat - AI Chat App (z-ai-web-dev-sdk)

Aplikasi chat AI Android berbasis Flutter yang menjalankan model GGUF secara lokal dan menggunakan **z-ai-web-dev-sdk** (GLM 5.1) sebagai fallback melalui MCP (Model Context Protocol).

## Perubahan Terbaru

- **z-ai-web-dev-sdk**: Diganti dari raw HTTP ke Dart port of z-ai-web-dev-sdk
- **JWT Authentication**: Generate JWT token dari API key (format id.secret) 
- **SDK Modules**: `chat.completions`, `functions.invoke`, `images.generations`

## Fitur

- **Inferensi GGUF Lokal**: Jalankan model AI dari file .gguf di perangkat
- **z-ai-web-dev-sdk Cloud**: GLM 5.1 via `zai.chat.completions.createStream()`
- **MCP Tools**: web_search, code_execute, image_analysis, knowledge_search
- **3 Mode Chat**: Local / GLM Cloud / Auto
- **JWT Auth**: Otomatis generate JWT dari API key Zhipu

## Cara Build Release APK

### Prasyarat

```bash
# 1. Flutter SDK 3.24+
flutter --version

# 2. JDK 17+ (FULL JDK, bukan JRE saja)
java -version
# Pastikan: jlink tersedia di $JAVA_HOME/bin/

# 3. Android SDK (34 atau 35)
flutter doctor
```

### Build

```bash
cd neural_chat

# Install dependencies
flutter pub get

# Build Release APK
flutter build apk --release

# APK output:
# build/app/outputs/flutter-apk/app-release.apk
```

### Build Troubleshooting

```bash
# Jika error Gradle cache:
cd android && ./gradlew clean && cd ..
flutter clean && flutter pub get
flutter build apk --release

# Jika error JDK (jlink not found):
export JAVA_HOME=/path/to/full/jdk
export PATH=$JAVA_HOME/bin:$PATH

# Jika error SDK version:
# Edit android/app/build.gradle: compileSdk = 35
sdkmanager "platforms;android-35"
```

## z-ai-web-dev-sdk Architecture

```
lib/services/z_ai_web_dev_sdk.dart   ← Dart port of z-ai-web-dev-sdk
├── class ZAI                    ← Main SDK class (ZAI.create())
│   ├── ChatCompletions          ← zai.chat.completions
│   │   ├── .create()            ← Non-streaming chat
│   │   └── .createStream()      ← Streaming chat
│   ├── Functions                ← zai.functions
│   │   └── .invoke(name, args)  ← Function calling
│   └── Images                   ← zai.images.generations
│       └── .create(prompt)      ← Image generation
│
lib/services/mcp_service.dart     ← MCP bridge using z-ai-web-dev-sdk
├── .chatWithMcp()               ← Streaming via zai.chat.completions.createStream()
├── .chatWithMcpSync()           ← Non-streaming via zai.chat.completions.create()
├── .executeTool()               ← Via zai.functions.invoke()
└── .getToolDefinitions()        ← MCP tools as function-calling schema

lib/providers/chat_provider.dart ← Uses ZAI instance directly
└── _generateCloud()             ← Streams via mcpService.chatWithMcp()
```

## API Key

API key GLM sudah dikonfigurasi default:
```
60507e439e404929b1c2e4fa5adb0410.3qvVGIPpqUtIVEvE
```
Bisa diubah di Settings > GLM API Key.

## Struktur Project

```
lib/
├── main.dart, app.dart
├── models/        ← chat_message, model_config, mcp_tool
├── services/
│   ├── z_ai_web_dev_sdk.dart   ← ★ z-ai-web-dev-sdk Dart port
│   ├── mcp_service.dart         ← MCP via z-ai-web-dev-sdk
│   ├── local_inference_service.dart ← GGUF inference
│   └── settings_service.dart    ← Persistence
├── providers/     ← chat_provider, settings_provider
├── screens/       ← chat, settings, model_management
└── widgets/       ← message_bubble, model_selector, typing_indicator
```
