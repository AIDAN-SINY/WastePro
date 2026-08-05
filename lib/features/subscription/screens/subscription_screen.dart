import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/subscription_service.dart';
import '../../../providers/user_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isProcessing = false;

  // Professional Payment Handshake Logic
  void _handleSubscription(String cycleName, double amount) async {
    setState(() => _isProcessing = true);
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final phone = userProvider.user!.phoneNumber;

    try {
      // 1. Simulate the Bank/MoMo API Handshake
      bool paymentSuccess = await SubscriptionService().simulatePayment(amount.toInt());

      if (paymentSuccess) {
        // 2. IMPLEMENT THE FLOW: Create the 'Contract' document linked to 'Frequency'
        // This follows the Manager's Class Diagram exactly
        await SubscriptionService().createContractFlow(phone, cycleName, amount);

        if (mounted) {
          // 3. Refresh user data to show the new active_contract_id
          await userProvider.refreshUser(phone);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Success! Your $cycleName contract is now active."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Return to Dashboard
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Service Plans", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // BACKGROUND (Using your new image)
          Image.asset(
            'assets/images/internal_bg.jpg', 
            width: double.infinity, 
            height: double.infinity, 
            fit: BoxFit.cover
          ),
          Container(color: Colors.black.withOpacity(0.6)),

          SafeArea(
            child: _isProcessing 
              ? const Center(child: CircularProgressIndicator(color: Colors.green))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildPlanCard("Monthly", 3000, "1 Collection per week", Icons.calendar_month),
                    _buildPlanCard("Weekly", 5500, "2 Collections per week", Icons.view_week),
                    _buildPlanCard("Daily", 15000, "Collection every single day", Icons.wb_sunny),
                    
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        "Secure checkout via SARA Money / MoMo",
                        style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                      ),
                    )
                  ],
                ),
          ),
        ],
      ),
    );
  }

  // --- MODERN GLASS UI HELPER ---
  Widget _buildPlanCard(String title, double price, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.withOpacity(0.2),
                      child: Icon(icon, color: Colors.greenAccent),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(subtitle, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${price.toInt()} XAF", style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                      ),
                      onPressed: () => _handleSubscription(title, price),
                      child: const Text("SUBSCRIBE"),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}