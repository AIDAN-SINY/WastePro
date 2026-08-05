import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Support & Help"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("How can we help?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _helpTile(Icons.question_answer, "Frequently Asked Questions", "Common issues and solutions"),
          _helpTile(Icons.phone, "Call Hotline", "Speak to a WastePro agent"),
          _helpTile(Icons.chat, "WhatsApp Support", "Fastest way to get help"),
          const SizedBox(height: 30),
          const Divider(),
          const Text("Legal Information", style: TextStyle(color: Colors.grey)),
          _helpTile(Icons.description, "Terms of Service", ""),
          _helpTile(Icons.privacy_tip, "Privacy Policy", ""),
        ],
      ),
    );
  }

  Widget _helpTile(IconData icon, String title, String sub) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: sub.isEmpty ? null : Text(sub),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () {},
    );
  }
}