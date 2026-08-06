import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import 'qr_scanner_screen.dart';
import 'pickup_schedule_screen.dart';

class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key});

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  bool _isOnline = false;
  int _currentIndex = 0;

  // --- COLORS MATCHING CLIENT DASHBOARD ---
  final Color voidBg = const Color(0xFF050F0C);
  final Color greenAccent = const Color(0xFF33D17E);
  final Color goldAccent = const Color(0xFFE8B94B);
  final Color iceText = const Color(0xFFEEF7F2);

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user!;

    // Dynamic Financial Data
    final double earnings = (user.toMap()['earnings'] ?? 0.0).toDouble();

    return Scaffold(
      backgroundColor: voidBg,
      body: Stack(
        children: [
          _buildRadialGlow(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOP STATUS ROW
                  _buildTopStatusRow(user, userProvider),
                  const SizedBox(height: 25),

                  // 2. WALLET CARD (Fintech Grade)
                  _buildWalletCard(earnings, userProvider),
                  const SizedBox(height: 15),

                  // 3. LOGISTICS MINI-MAP
                  _buildMiniMapWidget(),
                  const SizedBox(height: 15),

                  // 4. SCANNER CARD (Verification Handshake)
                  _buildScannerCard(user.phoneNumber, userProvider),
                  const SizedBox(height: 25),

                  // 5. PERFORMANCE STATS
                  _buildPerformanceStats(user),
                  const SizedBox(height: 15),

                  // 6. WEEKLY LEDGER PREVIEW
                  _buildLedgerPreview(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- UI BUILDING METHODS ---

  Widget _buildTopStatusRow(user, UserProvider userProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Operations Terminal",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(color: iceText, fontSize: 22, fontWeight: FontWeight.bold)),
              Text("${user.fullName} · Zone C",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: iceText.withOpacity(0.4), fontSize: 13)),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CUSTOM SWITCH (Online/Offline)
            GestureDetector(
              onTap: () => setState(() => _isOnline = !_isOnline),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isOnline ? greenAccent.withOpacity(0.1) : Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _isOnline ? greenAccent.withOpacity(0.5) : Colors.white12),
                ),
                child: Row(
                  children: [
                    Text(_isOnline ? "Online" : "Offline", style: TextStyle(color: _isOnline ? greenAccent : iceText.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 8),
                    Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: _isOnline ? greenAccent : Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // LOGOUT BUTTON
            IconButton(
              onPressed: () => userProvider.logout(),
              tooltip: 'Déconnexion',
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF6B5C), size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white10,
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildWalletCard(double amount, UserProvider provider) {
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("WALLET BALANCE", style: GoogleFonts.jetBrainsMono(color: iceText.withOpacity(0.4), fontSize: 10, letterSpacing: 1.5)),
              _statusPill("SARA Money", goldAccent),
            ],
          ),
          Text("${amount.toInt()} XAF", style: GoogleFonts.sora(color: iceText, fontSize: 32, fontWeight: FontWeight.bold)),
          Text("+8,150 XAF this week", style: TextStyle(color: greenAccent, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _btn("Withdraw", goldAccent, voidBg, () {})),
              const SizedBox(width: 10),
              Expanded(child: _btn("Statement", Colors.white.withOpacity(0.05), iceText, () {})),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniMapWidget() {
    return _glassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Container(
            height: 130, width: double.infinity,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: const Color(0xFF0A1F18)),
            child: const Center(child: Icon(Icons.grid_4x4, color: Colors.white10, size: 40)), // Mock grid
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("6 jobs in Zone C", style: GoogleFonts.inter(color: iceText, fontWeight: FontWeight.bold, fontSize: 14)),
                Text("Sorted by distance", style: TextStyle(color: iceText.withOpacity(0.4), fontSize: 10)),
              ]),
              _pillBtn("Open map", () {}),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildScannerCard(String collectorPhone, UserProvider provider) {
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.qr_code_scanner, size: 60, color: Color(0xFF33D17E)),
          const SizedBox(height: 15),
          Text("Scan client QR", style: GoogleFonts.sora(color: iceText, fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Confirms pickup and settles your commission instantly.", textAlign: TextAlign.center, style: TextStyle(color: iceText.withOpacity(0.4), fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: _btn("Verify work", greenAccent, voidBg, () => _showVerificationMenu(collectorPhone, provider))),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showManualDialog(collectorPhone, provider),
            child: Text("Lens dirty or raining? Enter code manually", style: TextStyle(color: iceText.withOpacity(0.3), fontSize: 11, decoration: TextDecoration.underline)),
          )
        ],
      ),
    );
  }

  Widget _buildPerformanceStats(user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _statBox("18", "SUCCESS", greenAccent),
        _statBox("1", "MISSED", const Color(0xFFFF6B5C)),
        _statBox("92%", "RECONCILED", goldAccent),
      ],
    );
  }

  Widget _buildLedgerPreview() {
    return _glassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          _ledgerRow("MON", "4 houses", "07:30 - 09:10", true),
          _ledgerRow("TUE", "3 houses", "07:20 - 08:40", true),
          _ledgerRow("WED", "5 houses", "In progress", false),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildRadialGlow() {
    return Container(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0.8, -0.6), radius: 1.0, colors: [greenAccent.withOpacity(0.08), Colors.transparent])));
  }

  Widget _glassCard({required Widget child, EdgeInsets? padding, BoxBorder? border}) {
    return ClipRRect(borderRadius: BorderRadius.circular(24), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: Container(padding: padding, decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: border ?? Border.all(color: Colors.white.withOpacity(0.08))), child: child)));
  }

  Widget _statBox(String v, String l, Color c) {
    return _glassCard(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      child: Column(children: [
        Text(v, style: GoogleFonts.sora(color: c, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(l, style: GoogleFonts.jetBrainsMono(color: iceText.withOpacity(0.4), fontSize: 8)),
      ]),
    );
  }

  Widget _ledgerRow(String day, String title, String sub, bool done) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day, style: GoogleFonts.jetBrainsMono(color: iceText.withOpacity(0.3), fontSize: 11)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(sub, style: TextStyle(color: iceText.withOpacity(0.4), fontSize: 10)),
          ]),
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? greenAccent : Colors.white10),
        ],
      ),
    );
  }

  Widget _btn(String t, Color bg, Color txt, VoidCallback onTap) => ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(t, style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 13)));
  Widget _pillBtn(String t, VoidCallback onTap) => TextButton(onPressed: onTap, style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: Text(t, style: TextStyle(color: iceText, fontSize: 11)));
  Widget _statusPill(String l, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(l, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold)));

  // --- LOGIC LINKS ---
  void _showVerificationMenu(String collectorPhone, UserProvider provider) {
    // Linked to your QRScanner and Database verifyAndPay logic
  }

  void _showManualDialog(String collectorPhone, UserProvider provider) {
    // Linked to Manual Entry logic
  }

  Widget _buildBottomNav() {
    // Pas de hauteur fixe : la barre s'adapte à son contenu (évite le
    // « bottom overflow » quand le contenu est plus haut que 65 px).
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
                icon: Icons.dashboard_rounded,
                label: "Dashboard",
                index: 0,
                onTap: () {
                  setState(() => _currentIndex = 0);
                },
              ),
              _buildNavItem(
                icon: Icons.qr_code_scanner_rounded,
                label: "Scan",
                index: 1,
                onTap: () {
                  setState(() => _currentIndex = 1);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                  );
                },
              ),
              _buildNavItem(
                icon: Icons.calendar_today_rounded,
                label: "Schedule",
                index: 2,
                onTap: () {
                  setState(() => _currentIndex = 2);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PickupScheduleScreen()),
                  );
                },
              ),
              _buildNavItem(
                icon: Icons.wallet_rounded,
                label: "Wallet",
                index: 3,
                onTap: () {
                  setState(() => _currentIndex = 3);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: greenAccent.withOpacity(0.2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? greenAccent.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isSelected 
                    ? Border.all(color: greenAccent.withOpacity(0.5), width: 1.5)
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected ? greenAccent : iceText.withOpacity(0.5),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? greenAccent : iceText.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}