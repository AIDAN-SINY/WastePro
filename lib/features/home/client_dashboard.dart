import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/user_provider.dart';
import '../../providers/navigation_provider.dart';
import '../subscription/screens/subscription_screen.dart';
import '../subscription/screens/history_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../auth/screens/welcome_screen.dart';
import 'notifications_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key, FirebaseFirestore? db}) : _db = db;

  /// Base injectée par les tests ; sinon l'instance par défaut.
  final FirebaseFirestore? _db;

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _scaleAnimation;

  // --- DESIGN COLORS (From design.html) ---
  final Color bgDark = const Color(0xFF0F3D2E);
  final Color bgDarker = const Color(0xFF0A2A20);
  final Color accentGold = const Color(0xFFE8A33D);
  final Color accentRed = const Color(0xFFC1443D);
  final Color cream = const Color(0xFFF5F1E8);
  final Color muted = const Color(0xFFAEC0B7);
  final Color dBg = const Color(0xFFF6F4EE);
  final Color dSurface = const Color(0xFFFFFFFF);
  final Color dBorder = const Color(0xFFEAE5D8);
  final Color dText = const Color(0xFF182620);
  final Color dMuted = const Color(0xFF7C8A80);
  final Color dGreen = const Color(0xFF0F3D2E);
  final Color dGreenSoft = const Color(0xFFE7EFE9);
  final Color dGold = const Color(0xFFE8A33D);
  final Color dGoldSoft = const Color(0xFFFBEDD6);
  final Color dRed = const Color(0xFFC1443D);
  final Color dRedSoft = const Color(0xFFF8E4E2);

  FirebaseFirestore get _db => widget._db ?? FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0.375).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutSine),
    );
    _animationController.repeat(reverse: true);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    final navProvider = Provider.of<NavigationProvider>(context);
    
    // Redirect to login if user is null (after logout)
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // App web : AuthWrapper (route '/') bascule déjà vers l'écran
        // d'accueil dès que le provider notifie. On pop simplement les
        // sous-écrans poussés au-dessus (ex. ProfileScreen) pour révéler
        // l'accueil du routeur — jamais de push impérative par-dessus le
        // routeur (elle forcerait à recharger la page pour se reconnecter).
        if (GoRouter.maybeOf(context) != null) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: dBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: 100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(user),
              const SizedBox(height: 6),

              _buildContractCard(user),
              const SizedBox(height: 22),

              _sectionTitle("Quick Access"),
              const SizedBox(height: 12),
              _buildQuickActions(),

              const SizedBox(height: 22),

              _sectionTitle("This Month"),
              const SizedBox(height: 12),
              _buildMonthlyStats(),

              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionTitle("Tracking"),
                  Text(
                    "Details",
                    style: TextStyle(
                      color: dGold,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildChartSection(),
              const SizedBox(height: 12),
              _buildCollectorTracking(),

              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionTitle("Recent Activity"),
                  Text(
                    "View All",
                    style: TextStyle(
                      color: dGold,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRecentActivity(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(navProvider),
    );
  }

  // --- UI BUILDING BLOCKS ---

  Widget _buildHeader(user) {
    final initials = user.fullName.split(' ').map((name) => name[0]).take(2).join();
    final firstName = user.fullName.split(' ')[0];
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    if (hour < 12) {
      greeting = "Good morning";
    } else if (hour < 18) {
      greeting = "Good afternoon";
    } else {
      greeting = "Good evening";
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: dGreen,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.sora(
                      color: cream,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$greeting, $firstName 👋",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        color: dText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: dMuted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            "Bonanjo, Douala",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: dMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _buildNotificationBell(user),
      ],
    );
  }

  /// Cloche de notifications : badge du nombre de notifications non lues
  /// (stream Firestore), ouverture de l'écran Notifications au tap.
  Widget _buildNotificationBell(user) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationsScreen(
              db: widget._db,
              phone: user.phoneNumber,
            ),
          ),
        );
      },
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: dSurface,
          shape: BoxShape.circle,
          border: Border.all(color: dBorder),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              color: dGreen,
              size: 18,
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('notifications')
                  .where('phone', isEqualTo: user.phoneNumber)
                  .snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? const [];
                final unread = docs
                    .where((d) => (d.data()['read'] as bool? ?? false) != true)
                    .length;
                if (unread == 0) return const SizedBox.shrink();
                return Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 15),
                    height: 15,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: dRed,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: dSurface, width: 1.2),
                    ),
                    child: Center(
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: TextStyle(
                          color: cream,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractCard(user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Circular countdown ring
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return SizedBox(
                width: 76,
                height: 76,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: _progressAnimation.value,
                    backgroundColor: cream.withOpacity(0.15),
                    foregroundColor: dGold,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "18",
                          style: GoogleFonts.sora(
                            color: cream,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          "h",
                          style: GoogleFonts.sora(
                            color: cream,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          "remaining",
                          style: TextStyle(
                            color: muted,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: dGold.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "STANDARD PLAN · 2x/WK",
                    style: TextStyle(
                      color: dGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.03,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Next pickup",
                  style: GoogleFonts.sora(
                    color: cream,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Tomorrow · 07:00 — Rue 1.234, Bonanjo",
                  style: TextStyle(
                    color: muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _actionItem(
          Icons.warning_amber_rounded,
          "Report Issue",
          dRedSoft,
          dRed,
        ),
        _actionItem(
          Icons.add,
          "Extra Pickup",
          dGoldSoft,
          dGold,
        ),
        _actionItem(
          Icons.description_outlined,
          "My Bill",
          dGreenSoft,
          dGreen,
        ),
        _actionItem(
          Icons.chat_bubble_outline,
          "Support",
          const Color(0xFFE7EEFB),
          const Color(0xFF3D6BE8),
        ),
      ],
    );
  }

  Widget _buildMonthlyStats() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [dGreen, dGreen.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: dGreen.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_scaleAnimation.value - 1.0) * 0.1,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cream.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: cream,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Upgrade to Premium",
                          style: GoogleFonts.sora(
                            color: cream,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Unlimited pickups & priority service",
                          style: TextStyle(
                            color: cream.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildPremiumFeature(
                      Icons.local_shipping_rounded,
                      "Unlimited Pickups",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPremiumFeature(
                      Icons.speed_rounded,
                      "Priority Service",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPremiumFeature(
                      Icons.support_agent_rounded,
                      "24/7 Support",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPremiumFeature(
                      Icons.verified_rounded,
                      "Eco Rewards",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dGold,
                    foregroundColor: const Color(0xFF2A1B05),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "View Plans",
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: cream,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: cream.withOpacity(0.9),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartSection() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dSurface,
        border: Border.all(color: dBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Waste Collected",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: dText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Last 6 months",
                style: TextStyle(
                  fontSize: 10,
                  color: dMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = ['Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Text(
                            months[value.toInt()],
                            style: TextStyle(
                              color: dMuted,
                              fontSize: 10,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: 18,
                        color: dGreen,
                        width: 22,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: 22,
                        color: dGreen,
                        width: 22,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: 19,
                        color: dGreen,
                        width: 22,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 3,
                    barRods: [
                      BarChartRodData(
                        toY: 25,
                        color: dGreen,
                        width: 22,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 4,
                    barRods: [
                      BarChartRodData(
                        toY: 21,
                        color: dGreen,
                        width: 22,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 5,
                    barRods: [
                      BarChartRodData(
                        toY: 24,
                        color: dGreen,
                        width: 22,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectorTracking() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dSurface,
        border: Border.all(color: dBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: dGoldSoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "PM",
                    style: GoogleFonts.sora(
                      color: dGold,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Paul Mbarga",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: dText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          "★★★★★",
                          style: TextStyle(
                            color: dGold,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "4.8",
                          style: TextStyle(
                            color: dMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F3EA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E8B57),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "On the way",
                      style: TextStyle(
                        color: const Color(0xFF2E8B57),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Route visualization
          SizedBox(
            height: 36,
            child: CustomPaint(
              painter: _RoutePainter(
                progress: 0.3,
                lineColor: dBorder,
                startColor: dGreen,
                endColor: dGold,
                truckColor: dGold,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    "15",
                    style: GoogleFonts.sora(
                      color: dGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "min · ETA",
                    style: TextStyle(
                      color: dMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: dGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Track",
                  style: TextStyle(
                    color: cream,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _sectionTitle(String t) => Text(
    t,
    style: GoogleFonts.sora(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: dText,
    ),
  );

  Widget _actionItem(IconData i, String l, Color bg, Color ic) {
    return InkWell(
      onTap: () {
        if (l.contains("My Bill"))
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          );
        if (l.contains("supp."))
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
          );
      },
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(i, color: ic, size: 19),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 70,
            child: Text(
              l,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: dText,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String value, String unit, String label) {
    return Container(
      width: (MediaQuery.of(context).size.width - 60) / 3,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: dSurface,
        border: Border.all(color: dBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.sora(
                  color: dGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                unit,
                style: GoogleFonts.sora(
                  color: dGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: dMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(NavigationProvider navProvider) {
    // Pas de hauteur fixe : la barre s'adapte à son contenu (évite le
    // « bottom overflow » quand le contenu est plus haut que 65 px).
    return Container(
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
              Expanded(
                child: _buildNavItem(
                  navProvider: navProvider,
                  icon: Icons.home_rounded,
                  label: "Home",
                  index: 0,
                  onTap: () {
                    navProvider.setIndex(0);
                  },
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  navProvider: navProvider,
                  icon: Icons.history_rounded,
                  label: "History",
                  index: 1,
                  onTap: () {
                    navProvider.setIndex(1);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  navProvider: navProvider,
                  icon: Icons.description_rounded,
                  label: "Bill",
                  index: 2,
                  onTap: () {
                    navProvider.setIndex(2);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildNavItem(
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

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dSurface,
        border: Border.all(color: dBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _activityItem(
            Icons.check_rounded,
            "Pickup completed",
            "Mon Jul 28 · 07:12",
            "4.2 kg",
            dGreenSoft,
            dGreen,
          ),
          _activityItem(
            Icons.check_rounded,
            "Pickup completed",
            "Fri Jul 25 · 07:05",
            "3.8 kg",
            dGreenSoft,
            dGreen,
          ),
          _activityItem(
            Icons.close,
            "Pickup missed",
            "Mon Jul 21 · rescheduled",
            "—",
            dRedSoft,
            dRed,
          ),
        ],
      ),
    );
  }

  Widget _activityItem(
    IconData icon,
    String title,
    String subtitle,
    String weight,
    Color bgColor,
    Color iconColor,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: dText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: dMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              weight,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: dMuted,
              ),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          height: 1,
          color: dBorder,
        ),
      ],
    );
  }
}

// Custom painter for the circular countdown ring
class _RingPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color foregroundColor;

  _RingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final strokeWidth = 6.0;

    // Background ring
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, backgroundPaint);

    // Foreground ring (progress)
    if (progress > 0) {
      final foregroundPaint = Paint()
        ..color = foregroundColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius);
      final startAngle = -math.pi / 2; // Start from top
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(rect, startAngle, sweepAngle, false, foregroundPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Custom painter for the route visualization
class _RoutePainter extends CustomPainter {
  final double progress;
  final Color lineColor;
  final Color startColor;
  final Color endColor;
  final Color truckColor;

  _RoutePainter({
    required this.progress,
    required this.lineColor,
    required this.startColor,
    required this.endColor,
    required this.truckColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final startX = 10.0;
    final endX = size.width - 10.0;
    final centerY = size.height / 2;

    // Draw the line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(startX, centerY),
      Offset(endX, centerY),
      linePaint,
    );

    // Draw start point
    final startPaint = Paint()
      ..color = startColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(startX, centerY), 5, startPaint);

    // Draw end point
    final endPaint = Paint()
      ..color = endColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(endX, centerY), 7, endPaint);

    // Draw end point border
    final endBorderPaint = Paint()
      ..color = endColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(endX, centerY), 7, endBorderPaint);

    // Draw truck position
    final truckX = startX + (endX - startX) * progress;
    
    // Draw ping effect
    final pingPaint = Paint()
      ..color = truckColor.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(truckX, centerY), 9, pingPaint);

    // Draw truck
    final truckPaint = Paint()
      ..color = truckColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(truckX, centerY), 6, truckPaint);
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
