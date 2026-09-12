/// Hugging Face Inference Providers — OpenAI-compatible chat completions.
library;

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class HuggingFaceChatService {
  HuggingFaceChatService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _url = 'https://router.huggingface.co/v1/chat/completions';

  String get _token => (dotenv.env['HF_TOKEN'] ?? '').trim();

  String get _model =>
      (dotenv.env['HF_MODEL'] ?? 'Qwen/Qwen2.5-7B-Instruct:fastest').trim();

  bool get isConfigured => _token.isNotEmpty && !_token.startsWith('hf_xxx');

  static const systemPromptFr = '''
Tu es WasteBot, l'assistant officiel de WastePro (collecte de dechets au Cameroun).
Reponds en francais, de facon courte, claire et amicale (3 a 8 phrases max).
N'utilise jamais d'emojis.

Tu connais :
- Plans : Monthly 3000 XAF (1 collecte/semaine), Weekly 5500 XAF (2/semaine), Daily 15000 XAF (tous les jours).
- Paiement CamPay (MTN MoMo / Orange Money). En demo CamPay debite 1 XAF meme si le plan affiche 3000+.
- Collectes, QR, notifications, plaintes, ramassage supplementaire (1000 XAF).
- Support : WhatsApp / appel +237 696 713 899, email support@wastepro.cm.

Si tu ne sais pas, propose de contacter le support humain.
Ne demande jamais de mot de passe, PIN ou cles API.
''';

  static const systemPromptEn = '''
You are WasteBot, the official WastePro assistant (waste collection in Cameroon).
Reply in English, short, clear and friendly (3 to 8 sentences max).
Never use emojis.

You know:
- Plans: Monthly 3000 XAF (1 pickup/week), Weekly 5500 XAF (2/week), Daily 15000 XAF (every day).
- CamPay payments (MTN MoMo / Orange Money). In demo CamPay charges 1 XAF even if the plan shows 3000+.
- Pickups, QR, notifications, complaints, extra pickup (1000 XAF).
- Support: WhatsApp / call +237 696 713 899, email support@wastepro.cm.

If unsure, suggest contacting human support.
Never ask for passwords, PINs or API keys.
''';

  /// Ask the model. [history] items are `{role: user|assistant, content: ...}`.
  Future<String> chat({
    required String userMessage,
    required bool french,
    List<Map<String, String>> history = const [],
  }) async {
    if (!isConfigured) {
      throw StateError(
        'HF_TOKEN missing. Add your Hugging Face token to .env then restart the app.',
      );
    }

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': french ? systemPromptFr : systemPromptEn,
      },
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    final response = await _http
        .post(
          Uri.parse(_url),
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _model,
            'messages': messages,
            'max_tokens': 450,
            'temperature': 0.4,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _extractError(response.body);
      throw StateError(
        detail ?? 'Hugging Face error (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw StateError('Empty AI response');
    }
    final message = choices[0]['message'];
    final content = (message is Map ? message['content'] : null)?.toString();
    if (content == null || content.trim().isEmpty) {
      throw StateError('Empty AI response');
    }
    return content.trim();
  }

  String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map) return err['message']?.toString();
        return (decoded['message'] ?? decoded['error'])?.toString();
      }
    } catch (_) {}
    if (body.trim().isEmpty) return null;
    return body.length > 180 ? '${body.substring(0, 180)}...' : body;
  }
}
