import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/user_provider.dart';
import '../../services/subscription_service.dart';
import '../subscription/screens/subscription_screen.dart';
import '../subscription/screens/history_screen.dart';
import '../auth/screens/map_picker_screen.dart';
import '../profile/screens/profile_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  bool _isActionLoading = false;

  // Professional Colors
  final Color greenPrimary = const Color(0xFF33D17E);
  final Color goldPrimary = const Color(0xFFE8B94B);

  // Logic: Calculate Days Remaining (Bank Requirement)
  int _calculateDaysRemaining(dynamic expiryDate) {
    if (expiryDate == null) return 0;
    DateTime expiry = (expiryDate as Timestamp).toDate();
    int difference = expiry.difference(DateTime.now()).inDays;
    return difference < 0 ? 0 : difference;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Fetch subscription details if they exist
    bool active = user.toMap()['isSubscribed'] ?? false;
    int daysLeft = 30; // Default or logic from your 'contracts' fetch

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("WASTEPRO", style: GoogleFonts.sora(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => userProvider.logout(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. BLURRED BACKGROUND (Modified as requested)
          Image.asset(
            'assets/images/internal_bg.jpg', 
            width: double.infinity, 
            height: double.infinity, 
            fit: BoxFit.cover
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),

          // 2. SCROLLABLE CONTENT (Previous Layout)
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome,", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  Text(user.fullName, style: GoogleFonts.sora(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 25),

                  // STATUS CARD
                  _buildStatusCard(user, active, daysLeft),
                  const SizedBox(height: 20),

                  // IMPACT STATS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _miniStat("Pickups", "12", Colors.greenAccent),
                      _miniStat("Kg Saved", "45", Colors.orangeAccent),
                      _miniStat("Score", "98%", Colors.blueAccent),
                    ],
                  ),

                  const SizedBox(height: 30),
                  const Text("Quick Actions", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  // ACTION GRID (RECONNECTED & FUNCTIONAL)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    children: [
                      _actionCard(Icons.payment, "Subscribe", Colors.blue, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                      }),
                      _actionCard(Icons.location_on, "Set Pin", Colors.red, () async {
                        final dynamic result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const MapPickerScreen()));
                        if (result != null && result is Map && context.mounted) {
                          setState(() => _isActionLoading = true);
                          await FirebaseFirestore.instance.collection('users').doc(user.phoneNumber).update({
                            'latitude': result['location'].latitude,
                            'longitude': result['location'].longitude,
                            'neighborhood': result['address'],
                          });
                          await userProvider.refreshUser(user.phoneNumber);
                          if (mounted) setState(() => _isActionLoading = false);
                        }
                      }),
                      _actionCard(Icons.bolt, "Urgent", Colors.orange, () => _showUrgentDialog(context, user.phoneNumber)),
                      _actionCard(Icons.history, "History", Colors.purple, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                      }),
                    ],
                  ),
                  const SizedBox(height: 100), // Space for fixed bar
                ],
              ),
            ),
          ),

          // 3. FIXED BOTTOM BAR (Requested Modification)
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: _glassContainer(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _helpBtn(Icons.chat, "WhatsApp", greenPrimary),
                  Container(width: 1, height: 20, color: Colors.white24),
                  _helpBtn(Icons.phone, "Call Center", Colors.white),
                ],
              ),
            ),
          ),

          if (_isActionLoading)
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.green))),
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildStatusCard(user, bool active, int daysLeft) {
    return _glassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Contract Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: active ? greenPrimary.withOpacity(0.2) : Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: Text(active ? "$daysLeft Days Left" : "Inactive", style: TextStyle(color: active ? greenPrimary : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 30),
          _kvRow("Pickup Day", user.toMap()['pickupDay'] ?? "Not scheduled"),
          _kvRow("Fixed Time", user.toMap()['pickupTime'] ?? "Not set"),
          const SizedBox(height: 10),
          if (active) LinearProgressIndicator(value: daysLeft / 30, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation(greenPrimary)),
        ],
      ),
    );
  }

  Widget _glassContainer({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: child,
        ),
      ),
    );
  }

  Widget _actionCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return _glassContainer(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String l, String v, Color c) {
    return Column(children: [
      Text(v, style: GoogleFonts.sora(color: c, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(l, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }

  Widget _kvRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _helpBtn(IconData i, String l, Color c) {
    return InkWell(
      onTap: () {}, // Support Logic
      child: Row(children: [Icon(i, color: c, size: 20), const SizedBox(width: 8), Text(l, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))]),
    );
  }

  void _showUrgentDialog(BuildContext context, String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1F18),
        title: const Text("Urgent Pickup", style: TextStyle(color: Colors.white)),
        content: const Text("Request an immediate collection for 500 XAF?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isActionLoading = true);
              await SubscriptionService().processOneTimePayment(phone, 500, "Urgent");
              await FirebaseFirestore.instance.collection('urgent_pickups').add({'userPhone': phone, 'timestamp': FieldValue.serverTimestamp(), 'status': 'paid'});
              if (mounted) setState(() => _isActionLoading = false);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }
}