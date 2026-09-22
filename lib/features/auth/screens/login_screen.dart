import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../providers/user_provider.dart';
import '../../../main.dart';
import 'registration_sreen.dart';

class LoginScreen extends StatefulWidget {
  final bool isNewUser;
  const LoginScreen({super.key, required this.isNewUser});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _fullPhoneNumber = '';
  bool _isLoading = false;
  bool _isNumberValid = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade800, Colors.green.shade50],
            stops: const [0.0, 0.4],
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.shield_outlined, size: 60, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              'WASTEPRO',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Login',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: InternationalPhoneNumberInput(
                      onInputChanged: (n) {
                        _fullPhoneNumber = n.phoneNumber ?? '';
                      },
                      onInputValidated: (v) =>
                          setState(() => _isNumberValid = v),
                      selectorConfig: const SelectorConfig(
                        selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                        showFlags: true,
                        useEmoji: false,
                        setSelectorButtonAsPrefixIcon: true,
                        leadingPadding: 15,
                      ),
                      initialValue: PhoneNumber(isoCode: 'CM'),
                      textFieldController: _phoneController,
                      inputDecoration: const InputDecoration(
                        hintText: 'Phone Number',
                        border: InputBorder.none,
                        suffixIcon: Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleAuth,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'CONNECT',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAuth() async {
    if (!_isNumberValid ||
        _fullPhoneNumber.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid credentials')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = await AuthService().login(
        _fullPhoneNumber,
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
      } else if (widget.isNewUser && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationScreen(
              phone: _fullPhoneNumber,
              initialPassword: _passwordController.text,
            ),
          ),
        );
      } else {
        throw 'User not found. Please register first.';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
