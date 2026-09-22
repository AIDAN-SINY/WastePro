/// Hugging Face Inference Providers config (from `.env`).
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class HuggingFaceConfig {
  HuggingFaceConfig._();

  static String _env(String key, {String fallback = ''}) {
    const defines = {
      'HF_TOKEN': String.fromEnvironment('HF_TOKEN'),
      'HF_MODEL': String.fromEnvironment('HF_MODEL'),
    };
    final fromDefine = defines[key] ?? '';
    if (fromDefine.isNotEmpty) return fromDefine;

    if (dotenv.isInitialized) {
      final value = dotenv.env[key];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }

  /// Personal access token with Inference Providers permission.
  static String get token => _env('HF_TOKEN');

  /// OpenAI-compatible model id, optionally with provider suffix (:fastest).
  static String get model =>
      _env('HF_MODEL', fallback: 'Qwen/Qwen2.5-7B-Instruct:fastest');

  static const String chatCompletionsUrl =
      'https://router.huggingface.co/v1/chat/completions';

  static bool get isConfigured => token.isNotEmpty;
}
