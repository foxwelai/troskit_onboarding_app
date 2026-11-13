import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/barcode_validator.dart';
import '../core/utils/sound_service.dart';

/// Simple barcode scanner — returns the scanned product barcode via `context.pop`.
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );
  bool _done = false;
  Timer? _settle;
  Timer? _warningTimer;
  String? _candidate;
  String? _warningMessage;
  int _hits = 0;

  @override
  void dispose() {
    _settle?.cancel();
    _warningTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final value = (barcode.rawValue ?? barcode.displayValue)?.trim();
      if (value == null || value.length < 4) continue;

      // Reject QR code links and invalid barcodes
      if (BarcodeValidator.isUrlOrLink(value)) {
        _showInvalidWarning('QR code web links cannot be used as barcodes');
        continue;
      }
      if (!BarcodeValidator.isValid(value)) {
        continue;
      }

      if (RegExp(r'^\d+$').hasMatch(value) && value.length < 5) continue;
      _absorb(value);
    }
  }

  void _showInvalidWarning(String message) {
    if (_warningMessage != null) return;
    setState(() => _warningMessage = message);
    _warningTimer?.cancel();
    _warningTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _warningMessage = null);
    });
  }

  void _absorb(String value) {
    if (_candidate == value) {
      _hits++;
    } else {
      _candidate = value;
      _hits = 1;
    }
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 280), () async {
      final code = _candidate;
      if (code == null || _done || !mounted) return;
      if (_hits < 2 && RegExp(r'^\d+$').hasMatch(code) && code.length <= 7) {
        return;
      }
      _done = true;
      await SoundService().playScanBeep();
      if (mounted) context.pop(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan barcode'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary, width: 2.5),
              ),
            ),
          ),
          if (_warningMessage != null)
            Positioned(
              top: 24,
              left: 20,
              right: 20,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _warningMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              'Align the barcode inside the frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
