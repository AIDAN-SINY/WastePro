import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart'; // Add this for the graph
import '../../providers/user_provider.dart';
import '../subscription/screens/subscription_screen.dart';
import '../subscription/screens/history_screen.dart';
import '../profile/screens/profile_screen.dart';
import 'chatbot_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  int _currentIndex = 0; // For Bottom Navigation

  // --- DESIGN COLORS (From your image) ---
  final Color primaryGreen = const Color(0xFF143626); // Deep Green
  final Color accentGreen = const Color(0xFF33D17E); // Bright Green
  final Color bgColor = const Color(0xFFF9F9F7); // Off-white

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      _buildHomeBody(user),
      const HistoryScreen(),
      const SubscriptionScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeBody(user) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(user),
            const SizedBox(height: 25),
            _buildHeroCard(user),
            const SizedBox(height: 30),
            _sectionTitle('Accès rapide'),
            const SizedBox(height: 15),
            _buildQuickActions(),
            const SizedBox(height: 30),
            _sectionTitle('Ce mois-ci'),
            const SizedBox(height: 15),
            _buildMonthlyStats(),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('Suivi'),
                Text(
                  'Détails',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildChartSection(),
            const SizedBox(height: 20),
            _buildCollectorTracking(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- UI BUILDING BLOCKS ---

  Widget _buildHeader(user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: primaryGreen,
              child: Text(
                user.displayInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    text: 'Bonjour, ',
                    style: GoogleFonts.inter(color: Colors.black, fontSize: 18),
                    children: [
                      TextSpan(
                        text: user.firstName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Text(
                  user.neighborhood ?? 'Cameroun',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(Icons.notifications_none, size: 22),
              ),
            ),
            InkWell(
              onTap: () {
                Provider.of<UserProvider>(context, listen: false).logout();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(
                  Icons.logout,
                  size: 22,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard(user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryGreen,
            primaryGreen.withValues(alpha: 0.85),
            const Color(0xFF1A5C3A),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Circular countdown
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 45,
                    height: 45,
                    child: CircularProgressIndicator(
                      value: 0.7,
                      strokeWidth: 4,
                      color: accentGreen,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  const Text(
                    "18h",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "FORMULE STANDARD - 2X/SEM.",
                  style: GoogleFonts.jetBrainsMono(
                    color: accentGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "Prochain ramassage",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "Demain - 07:00 - ${user.neighborhood ?? 'Point de collecte'}",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
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
          "Signaler un\nproblème",
          Colors.red[50]!,
          Colors.red,
        ),
        _actionItem(
          Icons.add,
          "Ramassage\nsupp.",
          Colors.orange[50]!,
          Colors.orange[800]!,
        ),
        _actionItem(
          Icons.description_outlined,
          "Ma facture",
          Colors.green[50]!,
          primaryGreen,
        ),
        _actionItem(
          Icons.chat_bubble_outline,
          "Support",
          Colors.blue[50]!,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildMonthlyStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _statBox("24kg", "Collectés"),
        _statBox("68%", "Taux recyclage"),
        _statBox("12kg", "CO2 évité"),
      ],
    );
  }

  Widget _buildChartSection() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: true), // Simplified for brevity
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: 8,
                  color: primaryGreen,
                  width: 15,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: 12,
                  color: primaryGreen,
                  width: 15,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
            BarChartGroupData(
              x: 2,
              barRods: [
                BarChartRodData(
                  toY: 10,
                  color: primaryGreen,
                  width: 15,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
            BarChartGroupData(
              x: 3,
              barRods: [
                BarChartRodData(
                  toY: 14,
                  color: primaryGreen,
                  width: 15,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectorTracking() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFFFDECD8),
            child: Text("PM", style: TextStyle(color: Colors.orange)),
          ),
          const SizedBox(width: 15),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Paul Mbarga",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  Icon(Icons.star, color: Colors.orange, size: 14),
                  Text(
                    " 4.8",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(radius: 3, backgroundColor: accentGreen),
                const Text(
                  " En route",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _sectionTitle(String t) => Text(
    t,
    style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold),
  );

  Widget _actionItem(IconData i, String l, Color bg, Color ic) {
    return InkWell(
      onTap: () {
        if (l.contains('Ma facture') || l.contains('facture')) {
          setState(() => _currentIndex = 1);
          return;
        }
        if (l.contains('supp.')) {
          setState(() => _currentIndex = 2);
          return;
        }
        if (l.contains('Support')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          );
          return;
        }
        if (l.contains('Signaler') || l.contains('problème')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          );
        }
      },
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Icon(i, color: ic),
          ),
          const SizedBox(height: 8),
          Text(
            l,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String v, String l) {
    return Container(
      width: 105,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: v.replaceAll(RegExp(r'[^0-9]'), ''),
              style: GoogleFonts.sora(
                color: primaryGreen,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(
                  text: v.replaceAll(RegExp(r'[0-9]'), ''),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Text(l, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Accueil",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "Historique",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            label: "Facture",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profil",
          ),
        ],
      ),
    );
  }
}
