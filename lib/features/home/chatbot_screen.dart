import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/huggingface_config.dart';
import '../../services/chatbot_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _service = ChatbotService();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_UiMessage> _messages = [];
  bool _busy = false;

  static const _quickPrompts = [
    'Quels sont les tarifs ?',
    'Comment payer avec MoMo ?',
    'Mon collecteur est en retard',
    'Comment activer mon abonnement ?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      _UiMessage(
        role: 'assistant',
        text: HuggingFaceConfig.isConfigured
            ? 'Bonjour ! Je suis l’assistant IA WastePro (Hugging Face). '
                'Pose ta question sur abonnements, paiements ou collectes.'
            : 'Bonjour ! Mode FAQ local actif. '
                'Ajoute HF_TOKEN dans ton fichier .env pour activer Hugging Face.',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _busy) return;

    setState(() {
      _messages.add(_UiMessage(role: 'user', text: text));
      _busy = true;
      _controller.clear();
    });
    _scrollToEnd();

    final history = _messages
        .where((m) => m.role != 'system')
        .take(_messages.length - 1)
        .map((m) => ChatMessage(role: m.role, content: m.text))
        .toList();

    // Keep last few turns only (token budget).
    final trimmed = history.length > 12
        ? history.sublist(history.length - 12)
        : history;

    try {
      final reply = await _service.send(
        history: trimmed,
        userMessage: text,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_UiMessage(role: 'assistant', text: reply));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _UiMessage(role: 'assistant', text: 'Désolé : $e'),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hfOn = HuggingFaceConfig.isConfigured;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assistant WastePro',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            Text(
              hfOn
                  ? 'Hugging Face - ${HuggingFaceConfig.model.split(':').first}'
                  : 'FAQ locale',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F3D2E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (!hfOn)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.orange.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ajoute HF_TOKEN (et optionnellement HF_MODEL) dans .env puis relance l\'app.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (_busy ? 1 : 0),
              itemBuilder: (context, index) {
                if (_busy && index == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: _TypingBubble(),
                    ),
                  );
                }
                final m = _messages[index];
                final isUser = m.role == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF1B7A4A)
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser && m.isAlert) ...[
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (!isUser && !m.isAlert) ...[
                          Icon(
                            Icons.smart_toy_outlined,
                            size: 18,
                            color: Colors.green.shade800,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            m.displayText,
                            style: GoogleFonts.poppins(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return ActionChip(
                  avatar: Icon(
                    i == 0
                        ? Icons.payments_outlined
                        : i == 1
                            ? Icons.phone_android
                            : i == 2
                                ? Icons.local_shipping_outlined
                                : Icons.verified_outlined,
                    size: 16,
                  ),
                  label: Text(
                    _quickPrompts[i],
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: _busy ? null : () => _send(_quickPrompts[i]),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ecris ton message...',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF1B7A4A),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _busy ? null : () => _send(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UiMessage {
  final String role;
  final String text;
  _UiMessage({required this.role, required this.text});

  bool get isAlert =>
      text.startsWith('[IA indisponible]') ||
      text.startsWith('[Connexion Hugging Face impossible]');

  String get displayText {
    if (!isAlert) return text;
    return text
        .replaceFirst('[IA indisponible]', 'IA indisponible')
        .replaceFirst(
          '[Connexion Hugging Face impossible]',
          'Connexion Hugging Face impossible',
        );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const SizedBox(
        width: 28,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
