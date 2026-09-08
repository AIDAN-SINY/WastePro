import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/two_factor_service.dart';
import '../../../models/user_model.dart';

/// Screen shown after login when 2FA is required (General Admin / Super Admin).
///
/// Displays a 6-digit OTP input field, a countdown timer, and a resend button.
/// On success, calls [onVerified] with the authenticated [UserModel].
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({
    super.key,
    required this.user,
    required this.service,
    required this.onVerified,
    this.devBypass = false,
  });

  final UserModel user;
  final TwoFactorService service;
  final VoidCallback onVerified;

  /// When true (debug builds), the screen shows a hint that any 6-digit
  /// code is accepted — matching [TwoFactorService.devBypass].
  final bool devBypass;

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  late final List<TextEditingController> _otp;
  late final List<FocusNode> _focusNodes;
  bool _verifying = false;
  String? _error;
  int _resendSeconds = 60;
  Timer? _resendTimer;
  bool _canResend = false;
  bool _otpSent = false;

  // Design system colors
  static const Color _dGreen = Color(0xFF0F3D2E);
  static const Color _dGold = Color(0xFFD4A853);
  static const Color _dMuted = Color(0xFF7C8A80);
  static const Color _dSurface = Color(0xFFFFFFFF);
  static const Color _dBg = Color(0xFFF5F7F6);
  static const Color _dBorder = Color(0xFFE8EBE9);
  static const Color _dText = Color(0xFF182620);

  @override
  void initState() {
    super.initState();
    _otp = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    _sendOtp();
  }

  @override
  void dispose() {
    for (final c in _otp) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final sent = await widget.service.initiate(
      uid: widget.user.uid ?? '',
      phone: widget.user.phoneNumber,
      email: null, // Email not stored in UserModel; SMS is primary channel
      fullName: widget.user.fullName,
    );
    if (mounted) {
      setState(() {
        _otpSent = true;
        if (!sent) {
          _error = 'Account temporarily locked. Please wait and try again.';
        }
      });
      _startResendTimer();
    }
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _canResend = false;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendOtp() async {
    setState(() {
      _error = null;
      for (final c in _otp) {
        c.clear();
      }
    });
    await widget.service.resend(
      uid: widget.user.uid ?? '',
      phone: widget.user.phoneNumber,
      fullName: widget.user.fullName,
    );
    if (mounted) {
      _startResendTimer();
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _verify() async {
    final code = _otp.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _error = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final error = await widget.service.verify(
        uid: widget.user.uid ?? '',
        enteredOtp: code,
      );

      if (!mounted) return;

      if (error == null) {
        // Success!
        widget.onVerified();
      } else {
        setState(() {
          _error = error;
          _verifying = false;
          // Clear OTP fields on error.
          for (final c in _otp) {
            c.clear();
          }
          _focusNodes[0].requestFocus();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred: $e';
          _verifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Lock icon ---
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _dGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 32,
                    color: _dGreen,
                  ),
                ),
                const SizedBox(height: 24),

                // --- Title ---
                Text(
                  'Two-Factor Authentication',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _dText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to your phone',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _dMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _dSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _dBorder),
                  ),
                  child: Text(
                    _maskPhone(widget.user.phoneNumber),
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _dGreen,
                    ),
                  ),
                ),

                // Dev mode hint (debug builds only) — the OTP is never
                // really received on demo numbers.
                if (widget.devBypass) ...[_DevHint()],

                const SizedBox(height: 32),

                // --- OTP Input ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return Container(
                      width: 46,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _otp[i],
                        focusNode: _focusNodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: GoogleFonts.sora(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _dText,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: _dSurface,
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _dBorder,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _dGreen,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (v) {
                          if (v.isNotEmpty && i < 5) {
                            _focusNodes[i + 1].requestFocus();
                          } else if (v.isEmpty && i > 0) {
                            _focusNodes[i - 1].requestFocus();
                          }
                          setState(() {}); // Update verify button state
                        },
                      ),
                    );
                  }),
                ),

                // --- Error message ---
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // --- Verify button ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _verifying ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _verifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'VERIFY',
                            style: GoogleFonts.sora(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- Resend ---
                if (_otpSent)
                  TextButton(
                    onPressed: _canResend ? _resendOtp : null,
                    child: Text(
                      _canResend
                          ? 'Resend Code'
                          : 'Resend in ${_resendSeconds}s',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _canResend ? _dGreen : _dMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                const SizedBox(height: 8),
                Text(
                  'This code expires in 5 minutes',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _dMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Masks phone number for display: +237 6XX XXX XX7
  String _maskPhone(String phone) {
    if (phone.length < 8) return phone;
    final prefix = phone.substring(0, 7); // +237 6X
    final suffix = phone.substring(phone.length - 2); // last 2 digits
    final middle = 'XXX XXX';
    return '$prefix $middle $suffix';
  }
}

/// Banner shown in debug builds: the OTP is not really sent to demo
/// numbers, so any 6-digit code is accepted.
class _DevHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F3D2E).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF0F3D2E).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.science_outlined,
              size: 18,
              color: Color(0xFF0F3D2E),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Dev mode: no SMS is sent to test numbers — enter any '
                '6-digit code to continue.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.35,
                  color: const Color(0xFF0F3D2E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
