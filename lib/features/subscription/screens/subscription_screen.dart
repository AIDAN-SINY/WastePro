import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config.dart';
import '../../../services/auth_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/subscription_service.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/navigation_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isProcessing = false;

  // Design System Colors
  final Color dBg = const Color(0xFFF5F7F6);
  final Color dSurface = const Color(0xFFFFFFFF);
  final Color dGreen = const Color(0xFF0F3D2E);
  final Color dGold = const Color(0xFFD4A853);
  final Color dMuted = const Color(0xFF7C8A80);
  final Color dBorder = const Color(0xFFE8EBE9);

  // Professional Payment Handshake Logic
  void _handleSubscription(String cycleName, double amount) async {
    setState(() => _isProcessing = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user!;
    final phone = user.phoneNumber;

    try {
      // 1. Paiement réel via l'API CamPay (MTN MoMo / Orange Money) :
      //    le client confirme la demande USSD avec son PIN sur son
      //    téléphone.
      final result = await PaymentService().charge(
        context: context,
        amount: amount,
        currency: AppConfig.currency,
        email: AuthService.emailFor(phone),
        phone: phone,
        name: user.fullName,
        title: '$cycleName plan',
        type: 'subscription',
        description: 'WastePro $cycleName subscription',
      );

      if (result.success) {
        // 2. IMPLEMENT THE FLOW: Create the 'Contract' document linked to 'Frequency'
        // This follows the Manager's Class Diagram exactly
        await SubscriptionService().createContractFlow(phone, cycleName, amount);

        // 3. Doc historique lu par l'écran « My Bill » / Payment History.
        await FirebaseFirestore.instance
            .collection('subscriptions')
            .doc(phone)
            .set({
          'planName': cycleName,
          'price': amount,
          'startDate': FieldValue.serverTimestamp(),
          'status': 'active',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Success! Your $cycleName contract is now active."),
              backgroundColor: dGreen,
            ),
          );
          Navigator.pop(context); // Return to Dashboard
          // 4. Refresh user data to show the new active_contract_id
          await userProvider.refreshUser(phone);
        }
      } else if (mounted) {
        // Paiement non confirmé (annulé/échec) : aucune charge n'a été faite.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment not completed — no charge was made.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);
    
    return Scaffold(
      backgroundColor: dBg,
      appBar: AppBar(
        title: Text("Service Plans", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: dGreen)),
        backgroundColor: dSurface,
        elevation: 0,
        foregroundColor: dGreen,
      ),
      body: _isProcessing 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F3D2E)))
        : SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Choose Your Plan",
                  style: GoogleFonts.sora(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: dGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Select a collection frequency that suits your needs",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: dMuted,
                  ),
                ),
                const SizedBox(height: 24),

                _buildPlanCard("Monthly", 3000, "1 Collection per week", Icons.calendar_month, false),
                _buildPlanCard("Weekly", 5500, "2 Collections per week", Icons.view_week, true),
                _buildPlanCard("Daily", 15000, "Collection every single day", Icons.wb_sunny, false),
                
                const SizedBox(height: 20),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 16, color: dMuted),
                      const SizedBox(width: 8),
                      Text(
                        "Secure checkout via CamPay (MTN MoMo / Orange Money)",
                        style: GoogleFonts.inter(color: dMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (AppConfig.isCampayDemo) ...[ 
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: dGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Demo mode — CamPay sandbox caps payments at "
                      "${AppConfig.campayDemoMaxAmount.toStringAsFixed(0)} XAF. "
                      "Your plan activates with a test charge; real prices apply "
                      "in production.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: dMuted, fontSize: 11, height: 1.4),
                    ),
                  ),
                ]
              ],
            ),
          ),
      bottomNavigationBar: _buildBottomNav(navProvider),
    );
  }

  Widget _buildPlanCard(String title, double price, String subtitle, IconData icon, bool isPopular) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPopular ? dGold.withOpacity(0.3) : dBorder,
          width: isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPopular ? dGold.withOpacity(0.15) : dGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon, 
                  color: isPopular ? dGold : dGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title, 
                          style: GoogleFonts.sora(
                            color: dGreen, 
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isPopular) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: dGold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "POPULAR",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle, 
                      style: GoogleFonts.inter(
                        color: dMuted, 
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${price.toInt()} XAF", 
                    style: GoogleFonts.sora(
                      color: dGreen, 
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "per cycle",
                    style: GoogleFonts.inter(
                      color: dMuted, 
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPopular ? dGold : dGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
                onPressed: () => _handleSubscription(title, price),
                child: Text(
                  "SUBSCRIBE",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              )
            ],
          )
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
                  Navigator.pushReplacementNamed(context, '/history');
                },
              ),
              _buildNavItem(
                navProvider: navProvider,
                icon: Icons.description_rounded,
                label: "Bill",
                index: 2,
                onTap: () {
                  navProvider.setIndex(2);
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