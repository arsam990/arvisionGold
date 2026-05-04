import 'package:flutter/material.dart';

/// Pulsing circular capture button.
///
/// • While idle — gold/signal-coloured with a gentle scale pulse animation.
/// • While scanning — shows a spinner and becomes non-interactive.
class CaptureButton extends StatefulWidget {
  final bool isScanning;
  final Color signalColor;
  final VoidCallback onPressed;

  const CaptureButton({
    super.key,
    required this.isScanning,
    required this.signalColor,
    required this.onPressed,
  });

  @override
  State<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<CaptureButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) {
        final scaleFactor = widget.isScanning ? 1.0 : _scale.value;
        return Transform.scale(
          scale: scaleFactor,
          child: GestureDetector(
            onTap: widget.isScanning ? null : widget.onPressed,
            child: Container(
              width: 74, height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.signalColor.withOpacity(0.85),
                    widget.signalColor.withOpacity(0.45),
                  ],
                ),
                border: Border.all(color: widget.signalColor, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color:      widget.signalColor.withOpacity(0.5),
                    blurRadius: 26,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: widget.isScanning
                  ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(
                      Icons.camera_enhance_rounded,
                      color: Colors.black,
                      size: 34,
                    ),
            ),
          ),
        );
      },
    );
  }
}
