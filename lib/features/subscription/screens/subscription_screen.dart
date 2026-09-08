import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config.dart';
import '../../../services/frequency_resolver.dart';
import '../../../services/subscription_service.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../payment/screens/checkout_screen.dart';
import '../../payment/screens/bills_screen.dart';
import '../../profile/screens/profile_screen.dart';
import 'history_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Design System Colors
  final Color dBg = const Color(0xFFF5F7F6);
  final Color dSurface = const Color(0xFFFFFFFF);
  final Color dGreen = const Color(0xFF0F3D2E);
  final Color dGold = const Color(0xFFD4A853);
  final Color dMuted = const Color(0xFF7C8A80);
  final Color dBorder = const Color(0xFFE8EBE9);

  // Zone calendar data fetched from Firestore.
  List<String> _zoneDays = [];
  String _zonePickupTime = '';
  String _zoneName = '';
  bool _zoneLoaded = false;

  // Dev bypass: when true, skip CamPay and auto-confirm.
  bool _devBypass = false;

  @override
  void initState() {
    super.initState();
    _loadZoneCalendar();
    _loadDevBypass();
  }



  /// Fetches the user's zone collection calendar from Firestore.
  Future<void> _loadZoneCalendar() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user == null) return;

    // Zone name is derived from the agency name (e.g. "Yaoundé — Bastos" → "Bastos").
    final raw = user.agenceName.trim();
    if (raw.isEmpty) return;
    final parts = raw.split(RegExp(r'[—–-]'));
    final zoneName = parts.length >= 2 ? parts.last.trim() : raw;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('zones')
          .where('name', isEqualTo: zoneName)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final days = (data['collectionDays'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final time = data['standardPickupTime'] as String? ?? '07:00 — 08:00';
        if (mounted) {
          setState(() {
            _zoneDays = days;
            _zonePickupTime = time;
            _zoneName = zoneName;
            _zoneLoaded = true;
          });
        }
      } else {
        if (mounted) setState(() => _zoneLoaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _zoneLoaded = true);
    }
  }

  /// Loads the dev bypass flag from Firestore.
  Future<void> _loadDevBypass() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _devBypass = doc.data()?['devPaymentBypass'] == true;
        });
      }
    } catch (_) {}
  }

  /// Maps plan title to a FrequencyTier.
  FrequencyTier _tierForPlan(String plan) => switch (plan.toLowerCase()) {
        'daily' => FrequencyTier.daily,
        'every 2 days' => FrequencyTier.every2Days,
        'weekly' => FrequencyTier.weekly,
        'monthly' => FrequencyTier.monthly,
        _ => FrequencyTier.weekly,
      };

  // Professional Payment Handshake Logic
  void _handleSubscription(String cycleName, double amount) async {
    final tier = _tierForPlan(cycleName);

    // --- Step 0: Day picker (if zone calendar exists and tier requires it) ---
    List<String> resolvedDays = [];
    if (_zoneLoaded && _zoneDays.isNotEmpty && FrequencyResolver.requiresDayChoice(tier)) {
      final chosen = await _showDayPickerDialog(tier);
      if (chosen == null || !mounted) return; // user cancelled
      resolvedDays = FrequencyResolver.resolve(
        zoneDays: _zoneDays,
        tier: tier,
        clientChosenDays: chosen,
      );
    } else if (_zoneDays.isNotEmpty && tier == FrequencyTier.daily) {
      resolvedDays = FrequencyResolver.resolve(
        zoneDays: _zoneDays,
        tier: tier,
      );
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user!;
    final phone = user.phoneNumber;

    if (_devBypass) {
      // Dev bypass: skip CamPay entirely, auto-confirm.
      await _finalizeSubscription(
        cycleName: cycleName,
        amount: amount,
        phone: phone,
        resolvedDays: resolvedDays,
        userProvider: userProvider,
      );
    } else {
      // Navigate to the CheckoutScreen — handles Campay Mobile Money flow.
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            amount: amount,
            description: 'WastePro $cycleName subscription',
            txRefPrefix: 'WP',
            onPaymentSuccess: () => _finalizeSubscription(
              cycleName: cycleName,
              amount: amount,
              phone: phone,
              resolvedDays: resolvedDays,
              userProvider: userProvider,
            ),
          ),
        ),
      );
    }
  }

  /// Creates the contract and subscription record after a confirmed payment.
  Future<void> _finalizeSubscription({
    required String cycleName,
    required double amount,
    required String phone,
    required List<String> resolvedDays,
    required UserProvider userProvider,
  }) async {
    try {
      // 1. Create contract with resolved collection days + pickup time.
      await SubscriptionService().createContractFlow(
        phone,
        cycleName,
        amount,
        resolvedDays: resolvedDays,
        pickupTime: _zonePickupTime,
        zoneName: _zoneName,
      );

      // 2. Doc historique lu par l'écran « My Bill » / Payment History.
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(phone)
          .set({
        'planName': cycleName,
        'price': amount,
        'startDate': FieldValue.serverTimestamp(),
        'status': 'active',
        'collection_days': resolvedDays,
        'pickup_time': _zonePickupTime,
        'zone_name': _zoneName,
      });

      if (mounted) {
        final daySummary = resolvedDays.isNotEmpty
            ? ' on ${resolvedDays.join(', ')}'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Success! Your $cycleName contract is now active$daySummary."),
            backgroundColor: dGreen,
          ),
        );
        Navigator.pop(context); // Return to Dashboard
        // 3. Refresh user data to show the new active_contract_id
        await userProvider.refreshUser(phone);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  /// Shows a dialog for the client to pick collection day(s) from the
  /// zone's existing calendar. Returns null if cancelled.
  Future<List<String>?> _showDayPickerDialog(FrequencyTier tier) async {
    final maxPick = FrequencyResolver.maxSelections(tier);
    final selected = <String>[];

    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            'Choose your collection day${maxPick > 1 ? 's' : ''}',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: dGreen),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${FrequencyResolver.label(tier)} plan — pick ${maxPick > 1 ? 'up to $maxPick' : '1'} day(s) from your zone (${_zoneName.isNotEmpty ? _zoneName : "your area"}).',
                style: GoogleFonts.inter(fontSize: 12, color: dMuted, height: 1.4),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _zoneDays.map((day) {
                  final isSelected = selected.contains(day);
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        if (isSelected) {
                          selected.remove(day);
                        } else if (selected.length < maxPick) {
                          selected.add(day);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? dGreen : dSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? dGreen : dBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        day,
                        style: GoogleFonts.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : dGreen,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_zonePickupTime.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.schedule_outlined, size: 14, color: dMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Pickup window: $_zonePickupTime',
                      style: GoogleFonts.inter(fontSize: 11, color: dMuted),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, color: dMuted)),
            ),
            TextButton(
              onPressed: selected.isEmpty ? null : () => Navigator.of(ctx).pop(selected.toList()),
              child: Text(
                'Confirm',
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected.isEmpty ? dMuted : dGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);
    
    return Scaffold(
      backgroundColor: dBg,
      appBar: AppBar(
        title: Text("Service Plans", style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: dGreen, fontSize: 16)),
        backgroundColor: dSurface,
        elevation: 0,
        foregroundColor: dGreen,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Choose Your Plan",
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: dGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Select a collection frequency that suits your needs",
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: dMuted,
                  ),
                ),
                const SizedBox(height: 18),

                _buildPlanCard("Monthly", 3000, "1 Collection per week", Icons.calendar_month, false),
                _buildPlanCard("Weekly", 5500, "2 Collections per week", Icons.view_week, true),
                _buildPlanCard("Daily", 15000, "Collection every single day", Icons.wb_sunny, false),
                
                const SizedBox(height: 14),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 13, color: dMuted),
                      const SizedBox(width: 6),
                      Text(
                        "Secure payment via CamPay",
                        style: TextStyle(color: dMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (AppConfig.isCampayDemo) ...[ 
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: dGold.withValues(alpha: 0.12),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? dGold.withValues(alpha: 0.3) : dBorder,
          width: isPopular ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPopular ? dGold.withValues(alpha: 0.15) : dGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon, 
                  color: isPopular ? dGold : dGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
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
                            fontSize: 14, 
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isPopular) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: dGold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "POPULAR",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle, 
                      style: TextStyle(
                        color: dMuted, 
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                      fontSize: 18, 
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    "per cycle",
                    style: TextStyle(
                      color: dMuted, 
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPopular ? dGold : dGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  elevation: 0,
                ),
                onPressed: () => _handleSubscription(title, price),
                child: Text(
                  "SUBSCRIBE",
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.3,
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
      decoration: BoxDecoration(
        color: dSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HistoryScreen(),
                    ),
                  );
                },
              ),
              _buildNavItem(
                navProvider: navProvider,
                icon: Icons.description_rounded,
                label: "Bill",
                index: 2,
                onTap: () {
                  navProvider.setIndex(2);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BillsScreen()),
                  );
                },
              ),
              _buildNavItem(
                navProvider: navProvider,
                icon: Icons.person_rounded,
                label: "Profile",
                index: 3,
                onTap: () {
                  navProvider.setIndex(3);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
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
      splashColor: dGreen.withValues(alpha: 0.1),              child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isSelected ? dGreen.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: isSelected 
                    ? Border.all(color: dGreen.withValues(alpha: 0.3), width: 1.5)
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected ? dGreen : dMuted,
                size: 21,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
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