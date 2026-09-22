import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/subscription_service.dart';
import '../../../services/payment_service.dart';
import '../../../providers/user_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isProcessing = false;
  String _statusMessage = '';

  Future<void> _handleSubscription(String cycleName, double amount) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final accountPhone = userProvider.user!.phoneNumber;

    final momoPhone = await _askMoMoPhone(accountPhone);
    if (momoPhone == null || momoPhone.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage =
          'Confirm the payment on your phone (MTN *126# / Orange #150*50#)...';
    });

    try {
      final paymentSuccess = await SubscriptionService().payWithCampay(
        phone: momoPhone.trim(),
        amount: amount.toInt(),
        planName: cycleName,
        accountUserId: accountPhone,
      );

      if (!paymentSuccess) {
        throw CampayException('Payment was not completed.');
      }

      await SubscriptionService().createContractFlow(
        accountPhone,
        cycleName,
        amount,
      );

      if (!mounted) return;

      await userProvider.refreshUser(accountPhone);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Success! Your $cycleName contract is now active.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });
      }
    }
  }

  Future<String?> _askMoMoPhone(String defaultPhone) async {
    final controller = TextEditingController(text: defaultPhone);

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'CamPay Mobile Money',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the MTN MoMo or Orange Money number that will pay.',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (6XXXXXXXX or 2376XXXXXXXX)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Pay with CamPay'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Service Plans',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: Navigator.canPop(context),
      ),
      body: Stack(
        children: [
          Image.asset(
            'assets/images/internal_bg.jpg',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withValues(alpha: 0.6)),
          SafeArea(
            child: _isProcessing
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.green),
                          const SizedBox(height: 20),
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildPlanCard(
                        'Monthly',
                        3000,
                        '1 Collection per week',
                        Icons.calendar_month,
                      ),
                      _buildPlanCard(
                        'Weekly',
                        5500,
                        '2 Collections per week',
                        Icons.view_week,
                      ),
                      _buildPlanCard(
                        'Daily',
                        15000,
                        'Collection every single day',
                        Icons.wb_sunny,
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'Secure checkout via CamPay (MTN MoMo / Orange Money)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    String title,
    double price,
    String subtitle,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      child: Icon(icon, color: Colors.greenAccent),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${price.toInt()} XAF',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () => _handleSubscription(title, price),
                      child: const Text('SUBSCRIBE'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
