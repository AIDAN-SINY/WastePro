import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/config.dart';
import '../features/payment/screens/payment_waiting_screen.dart';
import 'campay_service.dart';

/// Résultat d'une tentative de paiement.
class PaymentResult {
  const PaymentResult({
    required this.success,
    required this.status,
    this.txRef = '',
    this.transactionId = '',
  });

  /// Paiement confirmé réussi (status `successful`).
  final bool success;

  /// Statut final : successful | failed | cancelled.
  final String status;

  /// Référence externe générée côté app.
  final String txRef;

  /// Référence de transaction CamPay (vide si non confirmée).
  final String transactionId;
}

/// Service de paiement — encaisse via l'API REST CamPay (MTN MoMo /
/// Orange Money, Cameroun) puis enregistre la transaction dans Firestore
/// (`transactions/{txRef}`), qui alimente l'historique « My Bill ».
///
/// Flux : [charge] initie la collecte auprès du téléphone du client
/// ([CampayService.initCollect]) puis ouvre [PaymentWaitingScreen], qui
/// interroge CamPay jusqu'à la confirmation (PIN) du client.
class PaymentService {
  PaymentService({FirebaseFirestore? db, CampayService? campay})
      : _db = db ?? FirebaseFirestore.instance,
        _campay = campay ?? CampayService();

  final FirebaseFirestore _db;
  final CampayService _campay;

  /// Vrai quand le jeton CamPay a été configuré.
  bool get isConfigured => _campay.isConfigured;

  /// Montant réellement débité : en mode démo, plafonné à
  /// [AppConfig.campayDemoMaxAmount] (contrainte du bac à sable CamPay) ;
  /// sinon le montant demandé tel quel.
  double demoChargeableAmount(double amount) =>
      AppConfig.isCampayDemo && amount > AppConfig.campayDemoMaxAmount
          ? AppConfig.campayDemoMaxAmount
          : amount;

  /// Lance l'encaissement CamPay.
  ///
  /// - [phone] : numéro du client au format `+237...` (normalisé pour
  ///   CamPay automatiquement).
  /// - [type] : `'subscription'` | `'pickup'` (catégorie de transaction).
  /// - [txRefPrefix] : préfixe de la référence externe (ex. `WP`, `PICKUP`).
  ///
  /// Retourne un [PaymentResult] ; `success == true` uniquement si CamPay
  /// confirme le paiement (statut SUCCESSFUL).
  ///
  /// Lève une [String] ou [CampayException] si CamPay n'est pas configuré
  /// ou si l'initiation échoue.
  Future<PaymentResult> charge({
    required BuildContext context,
    required double amount,
    required String currency,
    String email = '',
    required String phone,
    String name = '',
    required String title,
    required String type,
    String description = '',
    String txRefPrefix = 'WP',
  }) async {
    if (!_campay.isConfigured) {
      throw 'CamPay is not configured. Build the app with '
          '--dart-define=CAMPAY_TOKEN=<your app token> '
          '(free demo token from demo.campay.net).';
    }
    if (amount <= 0) throw 'Invalid amount.';

    // Bac à sable CamPay : chaque transaction est plafonnée à
    // [AppConfig.campayDemoMaxAmount] XAF (ER201 au-delà). En mode démo on
    // débite donc ce plafond au lieu du prix réel du plan — le flux complet
    // (USSD → PIN → confirmation) reste testable de bout en bout.
    // En production (`www.campay.net`) aucun plafond : le prix réel passe.
    final charged = demoChargeableAmount(amount);

    final txRef = CampayService.newExternalReference(txRefPrefix);
    final initiated = await _campay.initCollect(
      amount: charged,
      currency: currency,
      from: CampayService.normalizePhone(phone),
      description: description.isEmpty ? title : description,
      externalReference: txRef,
    );

    // Écran d'attente : le client confirme sur son téléphone (PIN USSD).
    if (!context.mounted) {
      return PaymentResult(success: false, status: 'cancelled', txRef: txRef);
    }
    final waiting = await Navigator.of(context).push<PaymentWaitingResult>(
      MaterialPageRoute(
        builder: (_) => PaymentWaitingScreen(
          service: _campay,
          reference: initiated.reference,
          amount: charged,
          currency: currency,
          ussdCode: initiated.ussdCode,
          operator: initiated.operator,
        ),
      ),
    );

    final status = waiting?.status ?? 'cancelled';
    final transaction = waiting?.transaction;
    final result = PaymentResult(
      success: status == 'successful',
      status: status,
      txRef: txRef,
      transactionId: transaction?.reference ?? '',
    );

    await recordTransaction(
      phone: phone,
      amount: charged,
      currency: currency,
      type: type,
      title: title,
      result: result,
    );
    return result;
  }

  /// Enregistre la transaction dans `transactions/{txRef}` (historique du
  /// client). Un échec d'écriture ne fait jamais échouer le flux de
  /// paiement (l'historique est best-effort).
  Future<void> recordTransaction({
    required String phone,
    required double amount,
    required String currency,
    required String type,
    required String title,
    required PaymentResult result,
  }) async {
    try {
      await _db.collection('transactions').doc(result.txRef).set({
        'txRef': result.txRef,
        'transactionId': result.transactionId,
        'phone': phone,
        'userId': phone,
        'amount': amount,
        'currency': currency,
        'type': type,
        'description': title,
        'status': result.status,
        'paymentMethod': 'campay',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Silencieux : ne jamais bloquer l'utilisateur pour un historique.
    }
  }
}
