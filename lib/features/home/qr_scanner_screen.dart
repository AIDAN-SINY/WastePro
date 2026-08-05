import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatelessWidget {
  const QRScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Household QR"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        // The scanner detects the QR code
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              final String code = barcode.rawValue!;
              debugPrint('QR Code found! $code');
              // Return the scanned phone number back to the Dashboard
              Navigator.pop(context, code); 
              break; 
            }
          }
        },
      ),
    );
  }
}