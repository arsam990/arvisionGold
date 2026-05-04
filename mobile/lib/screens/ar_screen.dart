import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/constants.dart';
import '../models/prediction_model.dart';
import '../services/api_service.dart';
import '../widgets/capture_button.dart';
import '../widgets/hud_panel.dart';
import '../widgets/scan_reticle.dart';

/// The lifecycle state of a scan attempt.
enum ScanState { idle, scanning, result, error }

class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> with WidgetsBindingObserver {
  // ── Camera ──────────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  // ── State ───────────────────────────────────────────────────────────────────
  ScanState _scanState = ScanState.idle;
  PredictionModel? _prediction;
  String? _errorMessage;

  // ── Live price ──────────────────────────────────────────────────────────────
  LivePriceModel _livePrice = const LivePriceModel();
  Timer? _priceTimer;

  final ApiService _api = ApiService();

  // ────────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _startPricePoll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _priceTimer?.cancel();
    _api.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ── Camera init ─────────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _errorMessage = 'No camera found on device.');
        return;
      }
      final ctrl = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      if (!mounted) return;
      setState(() => _cameraController = ctrl);
    } on CameraException catch (e) {
      if (mounted) setState(() => _errorMessage = 'Camera: ${e.description}');
    }
  }

  // ── Live price polling ──────────────────────────────────────────────────────
  void _startPricePoll() {
    _fetchLivePrice();
    _priceTimer = Timer.periodic(
      AppConstants.pricePollInterval,
      (_) => _fetchLivePrice(),
    );
  }

  Future<void> _fetchLivePrice() async {
    try {
      final price = await _api.getLivePrice();
      if (mounted) setState(() => _livePrice = price);
    } catch (_) {
      // Silently ignore — price is non-critical
    }
  }

  // ── Capture & analyse ───────────────────────────────────────────────────────
  Future<void> _captureAndAnalyze() async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (_scanState == ScanState.scanning) return;

    setState(() {
      _scanState    = ScanState.scanning;
      _prediction   = null;
      _errorMessage = null;
    });

    try {
      final XFile xFile = await ctrl.takePicture();
      final result = await _api.predict(File(xFile.path));
      if (mounted) {
        setState(() {
          _prediction = result;
          _scanState  = ScanState.result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _scanState    = ScanState.error;
        });
      }
    }
  }

  // ── Derived values ──────────────────────────────────────────────────────────
  Color get _signalColor {
    if (_prediction == null) return const Color(AppConstants.colorGold);
    switch (_prediction!.severity.toLowerCase()) {
      case 'buy':  return const Color(AppConstants.colorGreen);
      case 'sell': return const Color(AppConstants.colorRed);
      default:     return const Color(AppConstants.colorNeutral);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraLayer(),
          _buildVignette(),
          _buildScanReticle(),
          _buildTopBar(),
          _buildHudPanel(),
          _buildCaptureButton(),
        ],
      ),
    );
  }

  // ── Layer: Camera ───────────────────────────────────────────────────────────
  Widget _buildCameraLayer() {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return Container(
        color: const Color(AppConstants.colorBg),
        child: Center(
          child: _errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                )
              : const CircularProgressIndicator(
                  color: Color(AppConstants.colorGold),
                ),
        ),
      );
    }
    // Fill the entire screen while preserving the camera's aspect ratio.
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width:  ctrl.value.previewSize!.height,
          height: ctrl.value.previewSize!.width,
          child: CameraPreview(ctrl),
        ),
      ),
    );
  }

  // ── Layer: Radial dark vignette ─────────────────────────────────────────────
  Widget _buildVignette() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
          ),
        ),
      ),
    );
  }

  // ── Layer: Animated scan reticle ────────────────────────────────────────────
  Widget _buildScanReticle() {
    return Positioned.fill(
      child: ScanReticle(
        color: _signalColor,
        isScanning: _scanState == ScanState.scanning,
      ),
    );
  }

  // ── Layer: Top bar ──────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    final price = _livePrice.price;
    final delta = _livePrice.delta;
    final isUp  = delta >= 0;
    final deltaColor = isUp
        ? const Color(AppConstants.colorGreen)
        : const Color(AppConstants.colorRed);

    final priceStr = price != null
        ? '\$ ${price.toStringAsFixed(2)}'
        : '\$ —';
    final deltaStr = price != null
        ? '${isUp ? "+" : ""}${delta.toStringAsFixed(2)} '
          '(${isUp ? "+" : ""}${_livePrice.pct.toStringAsFixed(3)}%)'
        : '';

    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.75), Colors.transparent],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Logo
                Text(
                  '◈ AR',
                  style: GoogleFonts.rajdhani(
                    color: const Color(AppConstants.colorGold),
                    fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 3,
                  ),
                ),
                Text(
                  'VISION GOLD',
                  style: GoogleFonts.rajdhani(
                    color: const Color(AppConstants.colorGold),
                    fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 3,
                  ),
                ),
                const Spacer(),
                // Live price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      priceStr,
                      style: GoogleFonts.shareTechMono(
                        color: const Color(AppConstants.colorGold),
                        fontSize: 15, fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (deltaStr.isNotEmpty)
                      Text(
                        deltaStr,
                        style: GoogleFonts.shareTechMono(
                          color: deltaColor, fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Layer: HUD panel ────────────────────────────────────────────────────────
  Widget _buildHudPanel() {
    // Panel appears only when there's something to show
    if (_scanState == ScanState.idle) return const SizedBox.shrink();

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 108),
          child: HudPanel(
            prediction:   _prediction,
            scanState:    _scanState,
            errorMessage: _errorMessage,
            signalColor:  _signalColor,
          ),
        ),
      ),
    );
  }

  // ── Layer: Capture button ───────────────────────────────────────────────────
  Widget _buildCaptureButton() {
    return Positioned(
      bottom: 30, left: 0, right: 0,
      child: SafeArea(
        top: false,
        child: Center(
          child: CaptureButton(
            isScanning:  _scanState == ScanState.scanning,
            signalColor: _signalColor,
            onPressed:   _captureAndAnalyze,
          ),
        ),
      ),
    );
  }
}
