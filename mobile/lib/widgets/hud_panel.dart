import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/prediction_model.dart';
import '../screens/ar_screen.dart';

/// Glassmorphic HUD panel that sits at the bottom of the AR screen.
///
/// Transitions automatically between:
///   • Scanning spinner
///   • Error message
///   • Full prediction result (metrics + signal badge + reason)
class HudPanel extends StatelessWidget {
  final PredictionModel? prediction;
  final ScanState scanState;
  final String? errorMessage;
  final Color signalColor;

  const HudPanel({
    super.key,
    required this.prediction,
    required this.scanState,
    required this.errorMessage,
    required this.signalColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.52),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: signalColor.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color:      signalColor.withOpacity(0.18),
                blurRadius: 28,
                spreadRadius: 0,
              ),
            ],
          ),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // ── Scanning ────────────────────────────────────────────────────────────
    if (scanState == ScanState.scanning) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2, color: signalColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'ANALYSING CHART…',
            style: GoogleFonts.shareTechMono(
              color: signalColor, fontSize: 13, letterSpacing: 2,
            ),
          ),
        ],
      );
    }

    // ── Error ───────────────────────────────────────────────────────────────
    if (scanState == ScanState.error || errorMessage != null) {
      return Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFF1744), size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage ?? 'An unknown error occurred.',
              style: GoogleFonts.shareTechMono(
                color: const Color(0xFFFF1744), fontSize: 11, height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    // ── Result ──────────────────────────────────────────────────────────────
    final p = prediction;
    if (p == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section label
        Text(
          'CONFLUENCE SIGNAL',
          textAlign: TextAlign.center,
          style: GoogleFonts.rajdhani(
            color: Colors.white38, fontSize: 11, letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 14),

        // Three metric tiles
        Row(
          children: [
            _MetricTile(
              label: 'PRICE',
              value: '\$ ${p.price.toStringAsFixed(2)}',
              valueColor: const Color(0xFFF0B90B),
            ),
            _MetricTile(
              label: 'VISION',
              value: p.chartCandle,
              valueColor: _candleColor(p.chartCandle),
            ),
            _MetricTile(
              label: 'AI TREND',
              value: p.aiTrend,
              valueColor: p.aiTrend == 'UP'
                  ? const Color(0xFF00E676)
                  : const Color(0xFFFF1744),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Signal badge
        _SignalBadge(signal: p.signal, signalColor: signalColor),
        const SizedBox(height: 12),

        // Reason text
        Text(
          p.reason,
          textAlign: TextAlign.center,
          style: GoogleFonts.shareTechMono(
            color: Colors.white54, fontSize: 11, height: 1.5,
          ),
        ),
      ],
    );
  }

  Color _candleColor(String candle) {
    switch (candle.toUpperCase()) {
      case 'GREEN':   return const Color(0xFF00E676);
      case 'RED':     return const Color(0xFFFF1744);
      default:        return const Color(0xFF90A4AE);
    }
  }
}

// ── Internal widgets ─────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color  valueColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.rajdhani(
              color: Colors.white38, fontSize: 10, letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.shareTechMono(
              color: valueColor, fontSize: 14, fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalBadge extends StatelessWidget {
  final String signal;
  final Color  signalColor;

  const _SignalBadge({required this.signal, required this.signalColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: signalColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: signalColor.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: signalColor.withOpacity(0.28), blurRadius: 20),
        ],
      ),
      child: Text(
        signal,
        textAlign: TextAlign.center,
        style: GoogleFonts.shareTechMono(
          color: signalColor,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 4,
          shadows: [Shadow(color: signalColor, blurRadius: 16)],
        ),
      ),
    );
  }
}
