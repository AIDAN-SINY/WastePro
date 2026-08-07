import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/navigation_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Design System Colors
  final Color dBg = const Color(0xFFF5F7F6);
  final Color dSurface = const Color(0xFFFFFFFF);
  final Color dGreen = const Color(0xFF0F3D2E);
  final Color dGold = const Color(0xFFD4A853);
  final Color dMuted = const Color(0xFF7C8A80);
  final Color dBorder = const Color(0xFFE8EBE9);

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user!;
    final navProvider = Provider.of<NavigationProvider>(context);

    return Scaffold(
      backgroundColor: dBg,
      appBar: AppBar(
        title: Text("Payment History", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: dGreen)),
        backgroundColor: dSurface,
        elevation: 0,
        foregroundColor: dGreen,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // For a prototype, we check the user's active sub document
        stream: FirebaseFirestore.instance.collection('subscriptions').doc(user.phoneNumber).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: dMuted.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    "No subscription history found.",
                    style: GoogleFonts.inter(color: dMuted, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final startDate = (data['startDate'] as Timestamp).toDate();
          
          return SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Payment History",
                  style: GoogleFonts.sora(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: dGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Track your subscription payments",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: dMuted,
                  ),
                ),
                const SizedBox(height: 24),

                _buildTransactionCard(
                  "${data['planName']} Plan",
                  "${data['price']} XAF",
                  "${startDate.day}/${startDate.month}/${startDate.year}",
                  "SUCCESS",
                  Icons.receipt_long,
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(navProvider),
    );
  }

  Widget _buildTransactionCard(String title, String amount, String date, String status, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: dGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: dGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.sora(
                    color: dGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Paid: $amount",
                  style: GoogleFonts.inter(
                    color: dMuted,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "Date: $date",
                  style: GoogleFonts.inter(
                    color: dMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: dGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                color: dGreen,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(NavigationProvider navProvider) {
    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: dSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                navProvider: navProvider,
                icon: Icons.home_rounded,
                label: "Home",
                index: 0,
                onTap: () {
                  navProvider.setIndex(0);
                  Navigator.pop(context);
                },
              ),
              _buildNavItem(
                navProvider: navProvider,
                icon: Icons.history_rounded,
                label: "History",
                index: 1,
                onTap: () {
                  navProvider.setIndex(1);
                },
              ),
              _buildNavItem(
                navProvider: navProvider,
                icon: Icons.description_rounded,
                label: "Bill",
                index: 2,
                onTap: () {
                  navProvider.setIndex(2);
                  Navigator.pushReplacementNamed(context, '/subscription');
                },
              ),
              _buildNavItem(
                navProvider: navProvider,
                icon: Icons.person_rounded,
                label: "Profile",
                index: 3,
                onTap: () {
                  navProvider.setIndex(3);
                  Navigator.pushReplacementNamed(context, '/profile');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required NavigationProvider navProvider,
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = navProvider.currentIndex == index;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: dGreen.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? dGreen.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isSelected 
                    ? Border.all(color: dGreen.withOpacity(0.3), width: 1.5)
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected ? dGreen : dMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? dGreen : dMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}