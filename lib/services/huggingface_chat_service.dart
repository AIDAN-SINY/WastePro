/// Hugging Face Inference Providers — OpenAI-compatible chat completions.
library;

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Safe error for UI — never expose HF account names or raw API payloads.
class HuggingFaceChatException implements Exception {
  const HuggingFaceChatException({
    required this.code,
    required this.userMessageFr,
    required this.userMessageEn,
  });

  final String code;
  final String userMessageFr;
  final String userMessageEn;

  String messageFor({required bool french}) =>
      french ? userMessageFr : userMessageEn;

  @override
  String toString() => 'HuggingFaceChatException($code)';
}

class HuggingFaceChatService {
  HuggingFaceChatService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _url = 'https://router.huggingface.co/v1/chat/completions';

  String get _token => (dotenv.env['HF_TOKEN'] ?? '').trim();

  String get _model =>
      (dotenv.env['HF_MODEL'] ?? 'Qwen/Qwen2.5-7B-Instruct:fastest').trim();

  bool get isConfigured =>
      _token.isNotEmpty &&
      !_token.startsWith('hf_xxx') &&
      _token.startsWith('hf_');

  static const systemPromptFr = '''
Tu es WasteBot, l'assistant officiel de WastePro (collecte de dechets au Cameroun).
Reponds en francais, de facon courte, claire et amicale (3 a 8 phrases max).
N'utilise jamais d'emojis.
Ne mentionne jamais de noms de comptes techniques, tokens, cles API ou usernames internes.

Tu connais :
- Plans : Monthly 3000 XAF (1 collecte/semaine), Weekly 5500 XAF (2/semaine), Daily 15000 XAF (tous les jours).
- Paiement CamPay (MTN MoMo / Orange Money). En demo CamPay debite 25 XAF meme si le plan affiche 3000+.
- Collectes, QR, notifications, plaintes, ramassage supplementaire (1000 XAF).
- Support : WhatsApp / appel +237 696 713 899, email support@wastepro.cm.

Si tu ne sais pas, propose de contacter le support humain.
Ne demande jamais de mot de passe, PIN ou cles API.
''';

  static const systemPromptEn = '''
You are WasteBot, the official WastePro assistant (waste collection in Cameroon).
Reply in English, short, clear and friendly (3 to 8 sentences max).
Never use emojis.
Never mention technical account names, tokens, API keys or internal usernames.

You know:
- Plans: Monthly 3000 XAF (1 pickup/week), Weekly 5500 XAF (2/week), Daily 15000 XAF (every day).
- CamPay payments (MTN MoMo / Orange Money). In demo CamPay charges 25 XAF even if the plan shows 3000+.
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
      throw const HuggingFaceChatException(
        code: 'missing_token',
        userMessageFr:
            'L\'IA WasteBot n\'est pas configuree. Ajoute un jeton Hugging Face valide (HF_TOKEN) dans .env puis relance l\'app.',
        userMessageEn:
            'WasteBot AI is not configured. Add a valid Hugging Face token (HF_TOKEN) in .env and restart the app.',
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

    late final http.Response response;
    try {
      response = await _http
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
    } catch (_) {
      throw const HuggingFaceChatException(
        code: 'network',
        userMessageFr:
            'Impossible de joindre le service IA pour le moment. Reessaie dans un instant.',
        userMessageEn:
            'Could not reach the AI service right now. Please try again shortly.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpError(response.statusCode, response.body);
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const HuggingFaceChatException(
          code: 'empty',
          userMessageFr: 'L\'IA n\'a renvoye aucune reponse. Reessaie.',
          userMessageEn: 'The AI returned an empty response. Please try again.',
        );
      }
      final message = choices[0]['message'];
      final content = (message is Map ? message['content'] : null)?.toString();
      if (content == null || content.trim().isEmpty) {
        throw const HuggingFaceChatException(
          code: 'empty',
          userMessageFr: 'L\'IA n\'a renvoye aucune reponse. Reessaie.',
          userMessageEn: 'The AI returned an empty response. Please try again.',
        );
      }
      return _sanitizeAssistantText(content.trim());
    } on HuggingFaceChatException {
      rethrow;
    } catch (_) {
      throw const HuggingFaceChatException(
        code: 'parse',
        userMessageFr: 'Reponse IA invalide. Reessaie dans un instant.',
        userMessageEn: 'Invalid AI response. Please try again shortly.',
      );
    }
  }

  HuggingFaceChatException _mapHttpError(int status, String body) {
    final raw = _extractError(body)?.toLowerCase() ?? '';
    final permission = status == 403 ||
        raw.contains('permission') ||
        raw.contains('sufficient permissions') ||
        raw.contains('inference providers') ||
        raw.contains('forbidden');

    if (status == 401 || raw.contains('unauthorized') || raw.contains('invalid token')) {
      return const HuggingFaceChatException(
        code: 'unauthorized',
        userMessageFr:
            'Jeton Hugging Face invalide. Cree un nouveau token sur huggingface.co/settings/tokens puis mets a jour HF_TOKEN.',
        userMessageEn:
            'Invalid Hugging Face token. Create a new token at huggingface.co/settings/tokens and update HF_TOKEN.',
      );
    }

    if (permission) {
      return const HuggingFaceChatException(
        code: 'permission',
        userMessageFr:
            'Le jeton Hugging Face n\'a pas la permission Inference Providers. Cree un Fine-grained token avec « Make calls to Inference Providers », mets a jour HF_TOKEN, puis relance l\'app.',
        userMessageEn:
            'Your Hugging Face token lacks Inference Providers permission. Create a Fine-grained token with “Make calls to Inference Providers”, update HF_TOKEN, then restart the app.',
      );
    }

    if (status == 429 || raw.contains('rate')) {
      return const HuggingFaceChatException(
        code: 'rate_limit',
        userMessageFr:
            'Trop de requetes IA pour le moment. Attends un peu puis reessaie.',
        userMessageEn:
            'Too many AI requests right now. Please wait a moment and try again.',
      );
    }

    return const HuggingFaceChatException(
      code: 'upstream',
      userMessageFr:
          'Le service IA WasteBot est temporairement indisponible. Pose ta question autrement ou contacte le support.',
      userMessageEn:
          'WasteBot AI is temporarily unavailable. Try rephrasing or contact support.',
    );
  }

  String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map) return err['message']?.toString();
        if (err is String) return err;
        return decoded['message']?.toString();
      }
    } catch (_) {}
    return null;
  }

  /// Strip leaked account handles / raw API noise from model output.
  String _sanitizeAssistantText(String text) {
    var out = text;
    out = out.replaceAll(
      RegExp(r'\bdrraoulh\b', caseSensitive: false),
      'WastePro',
    );
    out = out.replaceAll(
      RegExp(r'\bon behalf of user\s+\S+', caseSensitive: false),
      '',
    );
    out = out.replaceAll(
      RegExp(r'Bad state:[^\n]*', caseSensitive: false),
      '',
    );
    return out.trim();
  }
}
