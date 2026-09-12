import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/config.dart';
import '../../../providers/user_provider.dart';
import '../controllers/checkout_controller.dart';
/// Écran de checkout — sélection du mode de paiement Mobile Money
/// (Orange Money / MTN Mobile Money) avec saisie de numéro et overlay de
/// progression pendant le traitement Campay.
///
/// Utilisation :
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => CheckoutScreen(
///     amount: 5500,
///     description: 'Weekly subscription',
///     onPaymentSuccess: () => Navigator.pop(context),
///   ),
/// ));
/// ```
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.amount,
    required this.description,
    this.externalReference,
    this.txRefPrefix = 'WP',
    this.onPaymentSuccess,
  });

  final num amount;
  final String description;
  final String? externalReference;
  final String txRefPrefix;
  final VoidCallback? onPaymentSuccess;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color _dGreen = Color(0xFF0F3D2E);
  static const Color _dGold = Color(0xFFD4A853);
  static const Color _dMuted = Color(0xFF7C8A80);
  static const Color _dSurface = Color(0xFFFFFFFF);
  static const Color _dBg = Color(0xFFF5F7F6);
  static const Color _dBorder = Color(0xFFE8EBE9);
  static const Color _dText = Color(0xFF182620);

  late final CheckoutController controller;
  late final String _tag;
  late final TextEditingController _phoneCtrl;
  bool _phonePrefillDone = false;

  @override
  void initState() {
    super.initState();
    _tag = 'checkout-${DateTime.now().microsecondsSinceEpoch}';
    controller = Get.put(
      CheckoutController(
        amount: widget.amount,
        description: widget.description,
        externalReference: widget.externalReference,
        txRefPrefix: widget.txRefPrefix,
        onPaymentSuccess: widget.onPaymentSuccess,
      ),
      tag: _tag,
    );
    _phoneCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_phonePrefillDone) return;
    _phonePrefillDone = true;
    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      var initialPhone = user?.phoneNumber.trim() ?? '';
      if (initialPhone.startsWith('237') && initialPhone.length > 9) {
        initialPhone = initialPhone.substring(3);
      }
      if (initialPhone.isNotEmpty) {
        _phoneCtrl.text = initialPhone;
        controller.phoneNumber.value = initialPhone;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    if (Get.isRegistered<CheckoutController>(tag: _tag)) {
      Get.delete<CheckoutController>(tag: _tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    controller.bindHost(context);
    return Scaffold(
      backgroundColor: _dBg,
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: GoogleFonts.sora(
            fontWeight: FontWeight.w600,
            color: _dGreen,
            fontSize: 16,
          ),
        ),
        backgroundColor: _dSurface,
        elevation: 0,
        foregroundColor: _dGreen,
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Main content.
          Obx(() {
            if (controller.isProcessing.value) {
              return const SizedBox.shrink();
            }
            return _buildForm(context, controller);
          }),

          // Progress overlay (shown during payment processing).
          Obx(() {
            if (!controller.isProcessing.value) {
              return const SizedBox.shrink();
            }
            return _buildProgressOverlay(controller);
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Form
  // ---------------------------------------------------------------------------

  Widget _buildForm(BuildContext context, CheckoutController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Amount summary ---
          _buildAmountCard(controller),
          const SizedBox(height: 24),

          // --- Section title ---
          Text(
            'Payment Method',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _dText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how you want to pay',
            style: GoogleFonts.inter(fontSize: 12, color: _dMuted),
          ),
          const SizedBox(height: 14),

          // --- Mobile Money methods ---
          Obx(() => _buildMethodCard(
                context: context,
                controller: controller,
                method: PaymentMethod.orangeMoney,
                title: 'Orange Money',
                subtitle: 'Pay with your Orange Money account',
                icon: Icons.phone_iphone,
                accentColor: const Color(0xFFED7D31),
              )),
          const SizedBox(height: 10),
          Obx(() => _buildMethodCard(
                context: context,
                controller: controller,
                method: PaymentMethod.mtnMomo,
                title: 'MTN Mobile Money',
                subtitle: 'Pay with your MTN MoMo account',
                icon: Icons.phone_iphone,
                accentColor: const Color(0xFFFFCC00),
              )),
          const SizedBox(height: 10),

          // --- Credit card ---
          Obx(() => _buildMethodCard(
                context: context,
                controller: controller,
                method: PaymentMethod.creditCard,
                title: 'Credit / Debit Card',
                subtitle: 'Visa, Mastercard, or other cards',
                icon: Icons.credit_card,
                accentColor: const Color(0xFF3D6BE8),
              )),
          const SizedBox(height: 10),

          // --- Cash ---
          Obx(() => _buildMethodCard(
                context: context,
                controller: controller,
                method: PaymentMethod.cash,
                title: 'Cash',
                subtitle: 'Pay cash to the collector on pickup',
                icon: Icons.money,
                accentColor: const Color(0xFF1E9E5A),
              )),

          // --- Phone number input (only for Mobile Money) ---
          Obx(() {
            if (!controller.selectedMethod.value.requiresMobileMoney) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Phone Number',
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _dText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The payment request will be sent to this number',
                  style: GoogleFonts.inter(fontSize: 11, color: _dMuted),
                ),
                const SizedBox(height: 10),
                _buildPhoneInput(controller),
              ],
            );
          }),

          // --- Cash payment info ---
          Obx(() {
            if (controller.selectedMethod.value != PaymentMethod.cash) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EFE9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: _dGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cash payment will be collected by the collector '
                          'when your waste is picked up. Your subscription '
                          'will be activated upon confirmed collection.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _dGreen,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),

          // --- Card payment info ---
          Obx(() {
            if (controller.selectedMethod.value != PaymentMethod.creditCard) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EFE9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: Color(0xFF3D6BE8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Card payment is processed securely via our '
                          'payment partner. Your card details are never '
                          'stored on our servers.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _dGreen,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),

          const SizedBox(height: 28),

          // --- Demo mode notice ---
          if (AppConfig.isCampayDemo) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _dGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Demo mode - CamPay charges '
                '${controller.chargeableAmount.toStringAsFixed(0)} XAF '
                '(plan ${controller.displayAmount.toStringAsFixed(0)} XAF shown above). '
                'Real prices apply in production.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _dMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // --- Pay button ---
          SizedBox(
            width: double.infinity,
            child: Obx(() => ElevatedButton(
                  onPressed: controller.isProcessing.value
                      ? null
                      : () => controller.executePayment(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _payButtonText(controller),
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                )),
          ),
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 13, color: _dMuted),
                const SizedBox(width: 5),
                Text(
                  'Secure payment via Campay',
                  style: GoogleFonts.inter(color: _dMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Amount Card
  // ---------------------------------------------------------------------------

  Widget _buildAmountCard(CheckoutController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _dSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _dGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: _dGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.description,
                  style: GoogleFonts.sora(
                    color: _dText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total amount',
                  style: GoogleFonts.inter(color: _dMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.amount.toStringAsFixed(0)} XAF',
                style: GoogleFonts.sora(
                  color: _dGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (AppConfig.isCampayDemo)
                Text(
                  'Demo: ${controller.chargeableAmount.toStringAsFixed(0)} XAF',
                  style: GoogleFonts.inter(
                    color: _dGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Payment Method Card
  // ---------------------------------------------------------------------------

  Widget _buildMethodCard({
    required BuildContext context,
    required CheckoutController controller,
    required PaymentMethod method,
    required String title,
    required String subtitle,
    required IconData icon,
    Color accentColor = _dGreen,
  }) {
    final isSelected = controller.selectedMethod.value == method;

    return GestureDetector(
      onTap: () => controller.selectedMethod.value = method,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _dSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : _dBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Radio indicator.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : _dMuted.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            // Icon.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.12)
                    : _dBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? accentColor : _dMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Text.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? _dText : _dMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _dMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Check mark.
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: accentColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Phone Input
  // ---------------------------------------------------------------------------

  Widget _buildPhoneInput(CheckoutController controller) {
    return Container(
      decoration: BoxDecoration(
        color: _dSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dBorder),
      ),
      child: Row(
        children: [
          // Fixed prefix.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: _dBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              border: Border(
                right: BorderSide(color: _dBorder),
              ),
            ),
            child: Text(
              '+237',
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _dGreen,
              ),
            ),
          ),

          // Phone number field.
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.inter(fontSize: 14, color: _dText),
              decoration: InputDecoration(
                hintText: '6XX XXX XXX',
                hintStyle: GoogleFonts.inter(
                  color: _dMuted.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
              onChanged: (value) => controller.phoneNumber.value = value,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Progress Overlay
  // ---------------------------------------------------------------------------

  Widget _buildProgressOverlay(CheckoutController controller) {
    return Container(
      color: _dBg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _dGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smartphone,
                  color: _dGold,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),

              // Status text.
              Obx(() => Text(
                    controller.paymentStatus.value,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _dGreen,
                      height: 1.4,
                    ),
                  )),
              const SizedBox(height: 20),

              // Spinner (when NOT showing PIN field).
              Obx(() {
                if (controller.awaitingPin.value) {
                  return const SizedBox.shrink();
                }
                return const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: CircularProgressIndicator(color: _dGreen),
                );
              }),

              // PIN input field (when waiting for PIN).
              Obx(() {
                if (!controller.awaitingPin.value) {
                  return const SizedBox.shrink();
                }
                return _buildPinInput(controller);
              }),

              const SizedBox(height: 20),

              // Warning.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Do not close this screen',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PIN Input
  // ---------------------------------------------------------------------------

  Widget _buildPinInput(CheckoutController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _dSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title.
          Text(
            'Enter your Mobile Money PIN',
            style: GoogleFonts.sora(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _dText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your PIN will be sent securely to confirm the payment',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _dMuted,
            ),
          ),
          const SizedBox(height: 16),

          // PIN field.
          TextField(
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            style: GoogleFonts.sora(
              fontSize: 22,
              letterSpacing: 8,
              color: _dText,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '••••••',
              hintStyle: GoogleFonts.sora(
                fontSize: 22,
                letterSpacing: 8,
                color: _dMuted.withValues(alpha: 0.3),
              ),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _dBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _dGreen, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (value) => controller.pin.value = value,
          ),
          const SizedBox(height: 16),

          // Confirm button.
          SizedBox(
            width: double.infinity,
            child: Obx(() => ElevatedButton(
                  onPressed: controller.isProcessing.value
                      ? null
                      : () => controller.submitPin(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: controller.isProcessing.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'CONFIRM PAYMENT',
                          style: GoogleFonts.sora(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                        ),
                )),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _payButtonText(CheckoutController controller) => 'PAY';
}
