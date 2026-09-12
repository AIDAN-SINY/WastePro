import 'package:flutter/material.dart';

import 'chatbot_screen.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support & Help'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'How can we help?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _helpTile(
            context,
            Icons.smart_toy_outlined,
            'Chatbot IA WastePro',
            'Assistant Hugging Face (abonnements, paiement, collectes)',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatbotScreen()),
              );
            },
          ),
          _helpTile(
            context,
            Icons.question_answer,
            'Frequently Asked Questions',
            'Common issues and solutions',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatbotScreen()),
              );
            },
          ),
          _helpTile(
            context,
            Icons.phone,
            'Call Hotline',
            'Speak to a WastePro agent',
            () {},
          ),
          _helpTile(
            context,
            Icons.chat,
            'WhatsApp Support',
            'Fastest way to get help',
            () {},
          ),
          const SizedBox(height: 30),
          const Divider(),
          const Text('Legal Information', style: TextStyle(color: Colors.grey)),
          _helpTile(context, Icons.description, 'Terms of Service', '', () {}),
          _helpTile(context, Icons.privacy_tip, 'Privacy Policy', '', () {}),
        ],
      ),
    );
  }

  Widget _helpTile(
    BuildContext context,
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: sub.isEmpty ? null : Text(sub),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }
}
