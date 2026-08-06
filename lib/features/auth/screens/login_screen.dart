import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../providers/user_provider.dart';
import '../../../main.dart';
import 'registration_sreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Design colors from HTML
  final Color bgDark = const Color(0xFF0F3D2E);
  final Color bgDarker = const Color(0xFF0A2A20);
  final Color accentGold = const Color(0xFFE8A33D);
  final Color cream = const Color(0xFFF5F1E8);
  final Color muted = const Color(0xFFAEC0B7);
  final Color glass = const Color(0xFFF5F1E8).withOpacity(0.07);
  final Color glassBorder = const Color(0xFFF5F1E8).withOpacity(0.16);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutSine),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDarker,
      body: Stack(
        children: [
          // Animated background blobs
          _buildAnimatedBackground(),
          
          // Login content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 64),
              child: Column(
                children: [
                  // Logo/Mark
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 56,
                          height: 56,
                          margin: const EdgeInsets.only(bottom: 18),
                          child: Icon(
                            Icons.recycling_rounded,
                            color: accentGold,
                            size: 56,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Brand name
                  RichText(
                    text: TextSpan(
                      text: "Waste",
                      style: GoogleFonts.sora(
                        color: cream,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.02,
                      ),
                      children: [
                        TextSpan(
                          text: "Pro",
                          style: GoogleFonts.sora(
                            color: accentGold,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.02,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Tagline
                  Text(
                    "Ramassage d'ordures simplifié",
                    style: TextStyle(
                      color: muted,
                      fontSize: 13,
                    ),
                  ),
                  
                  const SizedBox(height: 36),
                  
                  // Login card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: glass,
                      border: Border.all(color: glassBorder),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Phone field
                        _buildLabel("Numéro de téléphone"),
                        _buildPhoneInput(),
                        
                        const SizedBox(height: 16),
                        
                        // Password field
                        _buildLabel("Mot de passe"),
                        _buildPasswordInput(),
                        
                        const SizedBox(height: 16),
                        
                        // Remember me & Forgot password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) => setState(() => _rememberMe = value ?? false),
                                  activeColor: accentGold,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                Text(
                                  "Se souvenir de moi",
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {},
                              child: Text(
                                "Mot de passe oublié ?",
                                style: TextStyle(
                                  color: accentGold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentGold,
                              foregroundColor: const Color(0xFF2A1B05),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF2A1B05),
                                    ),
                                  )
                                : Text(
                                    "Se connecter",
                                    style: GoogleFonts.sora(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 22),
                  
                  // Sign up hint
                  Text(
                    "Pas encore de compte ?",
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                    ),
                    child: Text(
                      "Créer un compte",
                      style: GoogleFonts.sora(
                        color: cream,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAuth() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs")),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Add +237 prefix if not present; strip spaces/dashes so the lookup
      // matches the canonical phone stored when the super admin created the
      // account (e.g. '+237 677 12 34 56' ⇄ '+237677123456').
      String phoneNumber = _phoneController.text.trim().replaceAll(
        RegExp(r'[\s-]'),
        '',
      );
      if (!phoneNumber.startsWith('+')) {
        // Gère aussi le « 237... » saisi sans le +.
        phoneNumber = phoneNumber.startsWith('237')
            ? '+$phoneNumber'
            : '+237$phoneNumber';
      }
      
      final user = await AuthService().login(
        phoneNumber,
        _passwordController.text,
      );
      
      if (user != null && mounted) {
        await Provider.of<UserProvider>(context, listen: false).setUser(user);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (route) => false,
          );
        }
      } else {
        throw "Utilisateur non trouvé. Veuillez vous inscrire d'abord.";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        Positioned(
          top: -60,
          left: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFF1C5A41),
              borderRadius: BorderRadius.circular(140),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          right: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: accentGold.withOpacity(0.16),
              borderRadius: BorderRadius.circular(110),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          left: MediaQuery.of(context).size.width * 0.4,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF0D2E22),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: TextStyle(
          color: muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.02,
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A2A20).withOpacity(0.35),
        border: Border.all(color: glassBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              "+237",
              style: TextStyle(
                color: muted,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: glassBorder,
          ),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(
                color: cream,
                fontSize: 14.5,
              ),
              decoration: InputDecoration(
                hintText: "6 XX XX XX XX",
                hintStyle: TextStyle(
                  color: muted.withOpacity(0.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A2A20).withOpacity(0.35),
        border: Border.all(color: glassBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(
                color: cream,
                fontSize: 14.5,
              ),
              decoration: InputDecoration(
                hintText: "••••••••",
                hintStyle: TextStyle(
                  color: muted.withOpacity(0.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: muted,
              size: 18,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ],
      ),
    );
  }
}
