import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../main.dart';
import '../../../models/user_model.dart';
import '../../../providers/user_provider.dart';
import '../../../services/auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  final String phone;
  final String initialPassword;

  const RegistrationScreen({
    super.key,
    required this.phone,
    required this.initialPassword,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  String? _selectedNeighborhood;
  String _selectedRole = 'client';
  bool _isLoading = false;
  bool _obs1 = true;
  bool _obs2 = true;

  final List<String> _neighborhoods = [
    'Yaoundé: Bastos',
    'Yaoundé: Mendong',
    'Yaoundé: Ngousso',
    'Yaoundé: Etoudi',
    'Douala: Akwa',
    'Douala: Bonamoussadi',
    'Douala: Bonapriso',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _passController.text = widget.initialPassword;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _showRetryDialog(String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Registration issue"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _handleRegister();
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.trim().isEmpty || _selectedNeighborhood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in your name and neighborhood"),
        ),
      );
      return;
    }

    if (_passController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newUser = UserModel(
        phoneNumber: widget.phone,
        fullName: _nameController.text.trim(),
        role: _selectedRole,
        password: _passController.text,
        neighborhood: _selectedNeighborhood,
      );

      await AuthService().register(newUser);

      if (mounted) {
        await Provider.of<UserProvider>(
          context,
          listen: false,
        ).setUser(newUser);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString();
        if (message.contains('temporarily unavailable') ||
            message.contains('No internet connection') ||
            message.contains('database service')) {
          await _showRetryDialog(message);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Create Profile", style: GoogleFonts.poppins()),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            Text(
              "Complete your account details",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            _buildTextField(_nameController, "Full Name", Icons.person_outline),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: _selectedNeighborhood,
              decoration: _inputDecoration(
                'Neighborhood / Zone',
                Icons.map_outlined,
              ),
              items: _neighborhoods
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedNeighborhood = val),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              decoration: _inputDecoration(
                'Account type',
                Icons.badge_outlined,
              ),
              items: const [
                DropdownMenuItem(value: 'client', child: Text('Client')),
                DropdownMenuItem(
                  value: 'collector',
                  child: Text('Collector'),
                ),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
            const SizedBox(height: 15),
            _buildTextField(
              _passController,
              'Password',
              Icons.lock_outline,
              isPassword: true,
              obscure: _obs1,
              toggle: () => setState(() => _obs1 = !_obs1),
            ),
            const SizedBox(height: 15),
            _buildTextField(
              _confirmPassController,
              "Confirm Password",
              Icons.check_circle_outline,
              isPassword: true,
              obscure: _obs2,
              toggle: () => setState(() => _obs2 = !_obs2),
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
                onPressed: _isLoading ? null : _handleRegister,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "FINISH",
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
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    bool isPass = false,
    bool obscure = false,
    VoidCallback? toggle,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 14),
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: isPass
          ? IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                size: 20,
              ),
              onPressed: toggle,
            )
          : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.green, width: 1),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? toggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? obscure : false,
      decoration: _inputDecoration(
        label,
        icon,
        isPass: isPassword,
        obscure: obscure,
        toggle: toggle,
      ),
    );
  }
}
