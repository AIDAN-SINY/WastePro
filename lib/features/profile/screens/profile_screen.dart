import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

import '../../../providers/user_provider.dart';
import '../../auth/screens/map_picker_screen.dart';
import '../../home/chatbot_screen.dart';
import '../../home/help_center_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _updateCollectionPoint(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user == null) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result == null) return;

    final location = result['location'];
    final address = result['address']?.toString();
    if (location is! ll.LatLng) return;

    await FirebaseFirestore.instance.collection('users').doc(user.phoneNumber).set({
      'latitude': location.latitude,
      'longitude': location.longitude,
      if (address != null && address.isNotEmpty) 'neighborhood': address,
    }, SetOptions(merge: true));

    await userProvider.refreshUser(user.phoneNumber);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Collection point updated'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Account'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.green,
              child: Text(
                user.displayInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              user.fullName.isEmpty ? 'User' : user.fullName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              'Account Type: ${user.role.toUpperCase()}',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (user.neighborhood != null) ...[
              const SizedBox(height: 4),
              Text(
                user.neighborhood!,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 30),
            _buildSectionTitle('Personal Information'),
            _buildInfoTile(Icons.phone, 'Phone Number', user.formattedPhone),
            _buildInfoTile(
              Icons.home,
              'Place of Residence',
              user.latitude != null
                  ? 'Pinned at: ${user.latitude!.toStringAsFixed(4)}, ${user.longitude!.toStringAsFixed(4)}'
                  : 'No location set yet',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Security & Services'),
            _buildActionTile(
              Icons.map_outlined,
              'Collection Point',
              'Update your GPS location',
              () => _updateCollectionPoint(context),
            ),
            _buildActionTile(
              Icons.support_agent,
              'Contact Support',
              'Talk to WastePro chatbot',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                );
              },
            ),
            _buildActionTile(
              Icons.help_outline,
              'Help Center',
              'FAQ and legal info',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                );
              },
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () => userProvider.logout(),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Colors.green.withValues(alpha: 0.1),
        child: Icon(icon, color: Colors.green, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(sub),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
    );
  }
}
