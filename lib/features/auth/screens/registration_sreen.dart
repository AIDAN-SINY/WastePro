import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../providers/user_provider.dart';

class RegistrationScreen extends StatefulWidget {
  final String uid;
  final String phone;

  const RegistrationScreen({super.key, required this.uid, required this.phone});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final AuthService _authService = AuthService();
  
  // Default role is 'client'
  String _selectedRole = 'client'; 
  bool _isLoading = false;

  void _register() async {
    String name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your full name")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 1. Create the UserModel object
    UserModel newUser = UserModel(
      uid: widget.uid,
      phoneNumber: widget.phone,
      fullName: name,
      role: _selectedRole,
      isVerified: _selectedRole == 'client' ? true : false, // Collectors need manual verification
    );

    try {
      // 2. Save to Firestore
      await _authService.createUserProfile(newUser);

      // 3. Update the Provider so the whole app knows who is logged in
      if (mounted) {
        await Provider.of<UserProvider>(context, listen: false).refreshUser(widget.uid);
        
        // TODO: Navigate to the appropriate Dashboard
        print("Registration Complete for ${newUser.role}");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Profile")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Final Step",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("Tell us a bit more about you."),
              const SizedBox(height: 30),
              
              // Name Field
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  hintText: "Enter your name or business name",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 30),
              
              const Text("I want to use Waste Pro as:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              // Role Selection (Radio buttons)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text("Household / Enterprise"),
                      subtitle: const Text("I want my waste collected"),
                      value: 'client',
                      groupValue: _selectedRole,
                      activeColor: Colors.green,
                      onChanged: (val) => setState(() => _selectedRole = val!),
                    ),
                    const Divider(height: 0),
                    RadioListTile<String>(
                      title: const Text("Collector"),
                      subtitle: const Text("I want to collect waste"),
                      value: 'collector',
                      groupValue: _selectedRole,
                      activeColor: Colors.green,
                      onChanged: (val) => setState(() => _selectedRole = val!),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Create Account"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}