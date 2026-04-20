import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/models/diagnostic_model.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _isAnalyzing = false;
  bool _torchOn = false;

  late AnimationController _cornerController;
  late Animation<double> _cornerAnim;
  late AnimationController _scanLineController;
  late Animation<double> _scanLine;

  final List<String> _thinkingLines = [
    "🔍 J'observe les composants...",
    "⚡ Détection d'anomalie en cours...",
    "🧠 Analyse thermique...",
    "✅ Diagnostic prêt !",
  ];
  final List<bool> _thinkingVisible = [false, false, false, false];

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initAnimations();
  }

  void _initAnimations() {
    // Animation coins du viewfinder
    _cornerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _cornerAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _cornerController, curve: Curves.easeInOut),
    );

    // Ligne de scan
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _scanLine = Tween<double>(begin: 0.0, end: 1.0).animate(_scanLineController);
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      _cameraController = CameraController(
        _cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Erreur caméra: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      _runAnalysis();
    }
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null || !_isCameraReady) return;
    setState(() => _torchOn = !_torchOn);
    await _cameraController!.setFlashMode(
      _torchOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      for (int i = 0; i < _thinkingVisible.length; i++) {
        _thinkingVisible[i] = false;
      }
    });

    // Affichage progressif des lignes de thinking
    for (int i = 0; i < _thinkingLines.length; i++) {
      await Future.delayed(Duration(milliseconds: 700 * (i + 1)));
      if (mounted) setState(() => _thinkingVisible[i] = true);
    }

    // TODO: LiteRT — Remplacer ce délai par l'inférence Gemma 4
    // final result = await GemmaInference.analyze(imagePath);
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      Navigator.pushNamed(
        context,
        '/result',
        arguments: DiagnosticModel.mock(),
      );
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _cornerController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Caméra ou fallback ──────────────────────────────────────────
          _isCameraReady && _cameraController != null
              ? CameraPreview(_cameraController!)
              : _buildCameraFallback(),

          // ── Overlay sombre haut ─────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Texte d'instruction ─────────────────────────────────────────
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Pointez vers l'objet à réparer",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // ── Viewfinder animé ────────────────────────────────────────────
          Center(child: _buildViewfinder()),

          // ── Overlay analyse ─────────────────────────────────────────────
          if (_isAnalyzing) _buildAnalysisOverlay(),

          // ── Overlay sombre bas ──────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 160,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Contrôles caméra ────────────────────────────────────────────
          if (!_isAnalyzing) _buildControls(),
        ],
      ),
    );
  }

  Widget _buildCameraFallback() {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined,
                color: AppTheme.primary.withOpacity(0.3), size: 64),
            const SizedBox(height: 16),
            Text(
              'Caméra non disponible',
              style: TextStyle(color: Colors.white.withOpacity(0.3)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinder() {
    return AnimatedBuilder(
      animation: _cornerAnim,
      builder: (context, child) {
        return SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            children: [
              // Ligne de scan animée
              if (!_isAnalyzing)
                AnimatedBuilder(
                  animation: _scanLine,
                  builder: (context, child) {
                    return Positioned(
                      top: _scanLine.value * 250,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppTheme.primary.withOpacity(0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Coins dorés
              _buildCorner(top: 0, left: 0),
              _buildCorner(top: 0, right: 0),
              _buildCorner(bottom: 0, left: 0),
              _buildCorner(bottom: 0, right: 0),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCorner({double? top, double? left, double? right, double? bottom}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: top != null
                ? BorderSide(color: AppTheme.primary, width: 3)
                : BorderSide.none,
            bottom: bottom != null
                ? BorderSide(color: AppTheme.primary, width: 3)
                : BorderSide.none,
            left: left != null
                ? BorderSide(color: AppTheme.primary, width: 3)
                : BorderSide.none,
            right: right != null
                ? BorderSide(color: AppTheme.primary, width: 3)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: top != null && left != null
                ? const Radius.circular(8)
                : Radius.zero,
            topRight: top != null && right != null
                ? const Radius.circular(8)
                : Radius.zero,
            bottomLeft: bottom != null && left != null
                ? const Radius.circular(8)
                : Radius.zero,
            bottomRight: bottom != null && right != null
                ? const Radius.circular(8)
                : Radius.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo pulsant
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.wb_sunny_rounded,
                  color: AppTheme.background, size: 35),
            ),
            const SizedBox(height: 24),
            Text(
              'TAARA ANALYSE...',
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Lignes de thinking progressives
            for (int i = 0; i < _thinkingLines.length; i++)
              AnimatedOpacity(
                opacity: _thinkingVisible[i] ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _thinkingLines[i],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Galerie
          _buildControlButton(
            icon: Icons.photo_library_outlined,
            onTap: _pickFromGallery,
          ),

          // Bouton capture principal
          GestureDetector(
            onTap: _runAnalysis,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppTheme.background, size: 30),
              ),
            ),
          ),

          // Torche
          _buildControlButton(
            icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            onTap: _toggleTorch,
            active: _torchOn,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? AppTheme.primary : Colors.white24,
          ),
        ),
        child: Icon(
          icon,
          color: active ? AppTheme.primary : Colors.white,
          size: 24,
        ),
      ),
    );
  }
}