import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/models/diagnostic_model.dart';
import 'package:taara/services/gemma_service.dart';
import 'package:taara/services/history_service.dart';
import 'package:taara/screens/voice_screen.dart';

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
  String _offlineDescription = ''; // Description saisie par l'utilisateur en mode offline

  late AnimationController _cornerController;
  late Animation<double> _cornerAnim;
  late AnimationController _scanLineController;
  late Animation<double> _scanLine;

  final List<String> _thinkingLines = [
    "🔍 Observation des composants...",
    "⚡ Détection d'anomalie en cours...",
    "🧠 Analyse avec Gemma 4...",
    "✅ Diagnostic prêt !",
  ];
  final List<bool> _thinkingVisible = [false, false, false, false];

  // Mode de connexion affiché pendant l'analyse
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initAnimations();
  }

  void _initAnimations() {
    _cornerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _cornerAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _cornerController, curve: Curves.easeInOut),
    );
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _scanLine =
        Tween<double>(begin: 0.0, end: 1.0).animate(_scanLineController);
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

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_isCameraReady || _isAnalyzing) return;
    try {
      final xFile = await _cameraController!.takePicture();
      await _runAnalysis(File(xFile.path));
    } catch (e) {
      debugPrint('Erreur capture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la capture')));
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isAnalyzing) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null && mounted) {
      await _runAnalysis(File(image.path));
    }
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null || !_isCameraReady) return;
    setState(() => _torchOn = !_torchOn);
    await _cameraController!.setFlashMode(
      _torchOn ? FlashMode.torch : FlashMode.off,
    );
  }

  // Dialog de sélection rapide quand l'appareil est hors-ligne
  // Retourne null si l'utilisateur annule
  Future<String?> _askOfflineDescription() async {
    final categories = [
      {'label': 'Moteur / Alternateur', 'value': 'moteur électrique alternateur'},
      {'label': 'Pompe à eau', 'value': 'pompe eau centrifuge'},
      {'label': 'Pompe solaire', 'value': 'pompe solaire immergée'},
      {'label': 'Carte électronique', 'value': 'carte électronique circuit'},
      {'label': 'Onduleur / Batterie', 'value': 'onduleur inverseur batterie'},
      {'label': 'Panneau solaire', 'value': 'panneau solaire photovoltaïque'},
      {'label': 'Réfrigérateur', 'value': 'réfrigérateur congélateur compresseur'},
      {'label': 'Groupe électrogène', 'value': 'groupe électrogène générateur'},
      {'label': 'Machine à laver', 'value': 'machine à laver'},
      {'label': 'Pompe à perfusion', 'value': 'pompe perfusion médical'},
      {'label': 'Concentrateur O₂', 'value': 'concentrateur oxygène médical'},
      {'label': 'Prise / Installation élec.', 'value': 'prise électrique installation'},
      {'label': 'Ordinateur / Téléphone', 'value': 'ordinateur téléphone smartphone'},
      {'label': 'Autre…', 'value': ''},
    ];

    String? selected;
    final TextEditingController manualCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1420),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.offline_bolt_rounded, color: Color(0xFFC9A84C), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Mode hors-ligne — Que scannez-vous ?',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Taara va chercher dans sa base locale (21 pannes).',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((cat) {
                  final isSelected = selected == cat['value'];
                  return GestureDetector(
                    onTap: () => setModalState(() => selected = cat['value']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFC9A84C).withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFC9A84C)
                              : Colors.white24,
                        ),
                      ),
                      child: Text(
                        cat['label']!,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFC9A84C)
                              : Colors.white70,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Champ texte libre si "Autre"
              if (selected == '') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: manualCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ex : prise électrique, ventilateur…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFFC9A84C), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Annuler',
                          style: TextStyle(color: Colors.white54)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selected == null
                          ? null
                          : () {
                              final val = selected == ''
                                  ? manualCtrl.text.trim()
                                  : selected!;
                              Navigator.pop(ctx, val);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC9A84C),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Analyser',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null) return null;
    return selected == '' ? manualCtrl.text.trim() : selected;
  }

  Future<void> _runAnalysis(File imageFile) async {
    setState(() {
      _isAnalyzing = true;
      _isOfflineMode = false;
      for (int i = 0; i < _thinkingVisible.length; i++) {
        _thinkingVisible[i] = false;
      }
    });

    // Vérifie la connectivité en amont pour adapter le message
    final online = await GemmaService.isOnline();
    if (mounted) setState(() => _isOfflineMode = !online);

    // Si hors-ligne : demander à l'utilisateur ce qu'il scanne
    // pour que la base de connaissances retourne le bon résultat
    String offlineHint = '';
    if (!online && mounted) {
      final desc = await _askOfflineDescription();
      if (desc == null) {
        // L'utilisateur a annulé
        if (mounted) setState(() => _isAnalyzing = false);
        return;
      }
      offlineHint = desc;
    }

    // Afficher les étapes de raisonnement progressivement
    for (int i = 0; i < _thinkingLines.length - 1; i++) {
      await Future.delayed(Duration(milliseconds: 800 * (i + 1)));
      if (mounted) setState(() => _thinkingVisible[i] = true);
    }

    // Appel Gemma 4 (online → KB avec hint → cache → erreur)
    final result = await GemmaService.analyzeImage(imageFile, offlineHint: offlineHint);

    if (mounted) setState(() => _thinkingVisible[3] = true);
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() => _isAnalyzing = false);

      // Sauvegarder dans l'historique
      await HistoryService.add(result.model);

      // Naviguer vers le résultat en passant le DiagnosticResult complet
      await Navigator.pushNamed(context, '/result', arguments: result);

      // Retourner le modèle au HomeScreen
      if (mounted) Navigator.pop(context, result.model);
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
          // Fond caméra
          _isCameraReady && _cameraController != null
              ? CameraPreview(_cameraController!)
              : _buildCameraFallback(),

          // Gradient haut
          Positioned(
            top: 0, left: 0, right: 0, height: 120,
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

          // Bouton retour + titre + bouton vocal
          Positioned(
            top: 48, left: 0, right: 0,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      "Pointez vers l'objet à réparer",
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const VoiceScreen()),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 5),
                        Text('VOCAL',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Viseur
          Center(child: _buildViewfinder()),

          // Overlay d'analyse
          if (_isAnalyzing) _buildAnalysisOverlay(),

          // Gradient bas
          Positioned(
            bottom: 0, left: 0, right: 0, height: 160,
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

          // Contrôles
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
            Text('Caméra non disponible',
                style: TextStyle(color: Colors.white.withOpacity(0.3))),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choisir depuis la galerie'),
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
          width: 260, height: 260,
          child: Stack(
            children: [
              if (!_isAnalyzing)
                AnimatedBuilder(
                  animation: _scanLine,
                  builder: (context, child) {
                    return Positioned(
                      top: _scanLine.value * 250, left: 10, right: 10,
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

  Widget _buildCorner(
      {double? top, double? left, double? right, double? bottom}) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Container(
        width: 32, height: 32,
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
                ? const Radius.circular(8) : Radius.zero,
            topRight: top != null && right != null
                ? const Radius.circular(8) : Radius.zero,
            bottomLeft: bottom != null && left != null
                ? const Radius.circular(8) : Radius.zero,
            bottomRight: bottom != null && right != null
                ? const Radius.circular(8) : Radius.zero,
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
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
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
            // Badge offline pendant l'analyse
            if (_isOfflineMode) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.offline_bolt_rounded,
                        color: AppTheme.primary, size: 12),
                    SizedBox(width: 6),
                    Text('Mode hors-ligne — cache local',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            for (int i = 0; i < _thinkingLines.length; i++)
              AnimatedOpacity(
                opacity: _thinkingVisible[i] ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_thinkingLines[i],
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 40, left: 20, right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildControlButton(
              icon: Icons.photo_library_outlined, onTap: _pickFromGallery),
          GestureDetector(
            onTap: _captureAndAnalyze,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Container(
                width: 68, height: 68,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppTheme.background, size: 30),
              ),
            ),
          ),
          _buildControlButton(
            icon: _torchOn
                ? Icons.flash_on_rounded
                : Icons.flash_off_rounded,
            onTap: _toggleTorch,
            active: _torchOn,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
      {required IconData icon,
      required VoidCallback onTap,
      bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
              color: active ? AppTheme.primary : Colors.white24),
        ),
        child: Icon(icon,
            color: active ? AppTheme.primary : Colors.white, size: 24),
      ),
    );
  }
}