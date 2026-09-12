/// WastePro support chatbot via Hugging Face Inference Providers
/// (OpenAI-compatible chat completions router).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/huggingface_config.dart';

class ChatMessage {
  final String role; // system | user | assistant
  final String content;

  const ChatMessage({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class ChatbotException implements Exception {
  final String message;
  ChatbotException(this.message);

  @override
  String toString() => message;
}

class ChatbotService {
  ChatbotService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const String systemPrompt = '''
Tu es l'assistant officiel de WastePro, une application de collecte de déchets au Cameroun.

Tu aides les clients en français (et en anglais si on te parle en anglais), de façon courte, claire et amicale.

Tu connais :
- Abonnements : Monthly 3000 XAF (1 collecte/semaine), Weekly 5500 XAF (2/semaine), Daily 15000 XAF (tous les jours).
- Paiement via CamPay (MTN Mobile Money / Orange Money). L'utilisateur confirme le paiement sur son téléphone (*126# MTN / #150*50# Orange).
- Le client peut suivre ses ramassages, son historique de paiement, et demander un ramassage supplémentaire.
- Les collecteurs scannent un QR pour valider une collecte.
- Support : problèmes de paiement, abonnement non activé, collecteur en retard, changement d'adresse GPS.

Règles :
- Ne demande jamais de mot de passe, PIN, ou clé API.
- Si tu ne sais pas, propose de contacter le support humain WastePro.
- Réponses courtes (3-6 phrases max), avec des étapes numérotées si besoin.
''';

  /// Local FAQ fallback when Hugging Face is not configured / unreachable.
  String localFaqReply(String userText) {
    final q = userText.toLowerCase();

    if (q.contains('prix') ||
        q.contains('tarif') ||
        q.contains('abonnement') ||
        q.contains('plan') ||
        q.contains('subscribe')) {
      return 'Plans WastePro :\n'
          '- Monthly - 3000 XAF (1 collecte/semaine)\n'
          '- Weekly - 5500 XAF (2 collectes/semaine)\n'
          '- Daily - 15000 XAF (tous les jours)\n'
          'Paiement via CamPay (MTN MoMo / Orange Money).';
    }

    if (q.contains('payer') ||
        q.contains('paiement') ||
        q.contains('momo') ||
        q.contains('campay') ||
        q.contains('orange')) {
      return 'Pour payer :\n'
          '1. Ouvre Abonnements et choisis un plan\n'
          '2. Entre ton numéro MTN ou Orange\n'
          '3. Valide sur ton téléphone (*126# ou #150*50#)\n'
          'Une fois SUCCESSFUL, ton contrat s’active automatiquement.';
    }

    if (q.contains('collect') ||
        q.contains('ramass') ||
        q.contains('pickup') ||
        q.contains('retard')) {
      return 'Pour un ramassage : ton abonnement doit être actif. '
          'Tu peux demander un ramassage supplémentaire depuis Accès rapide. '
          'Si le collecteur est en retard, signale le problème ou contacte le support.';
    }

    if (q.contains('bonjour') ||
        q.contains('salut') ||
        q.contains('hello') ||
        q.contains('hi')) {
      return 'Bonjour ! Je suis l’assistant WastePro. '
          'Je peux t’aider sur les abonnements, paiements CamPay, et collectes. Que veux-tu savoir ?';
    }

    return 'Je peux t’aider sur : abonnements, paiement CamPay (MoMo/OM), '
        'et collectes. Pose ta question plus précisément, ou ajoute HF_TOKEN '
        'dans .env pour activer l’IA Hugging Face.';
  }

  Future<String> send({
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    if (!HuggingFaceConfig.isConfigured) {
      return localFaqReply(userMessage);
    }

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history.map((m) => m.toJson()),
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await _http
          .post(
            Uri.parse(HuggingFaceConfig.chatCompletionsUrl),
            headers: {
              'Authorization': 'Bearer ${HuggingFaceConfig.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': HuggingFaceConfig.model,
              'messages': messages,
              'max_tokens': 400,
              'temperature': 0.4,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _extractError(response.body);
        return '[IA indisponible] (${detail ?? response.statusCode})\n\n'
            '${localFaqReply(userMessage)}';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) {
        return localFaqReply(userMessage);
      }

      final message = choices[0]['message'];
      final content = (message is Map ? message['content'] : null)?.toString();
      if (content == null || content.trim().isEmpty) {
        return localFaqReply(userMessage);
      }
      return content.trim();
    } catch (_) {
      return '[Connexion Hugging Face impossible]\n\n'
          '${localFaqReply(userMessage)}';
    }
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
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }
}
