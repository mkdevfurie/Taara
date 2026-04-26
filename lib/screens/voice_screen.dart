import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/models/diagnostic_model.dart';
import 'package:taara/services/gemma_service.dart';
import 'package:taara/services/history_service.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

enum _Mode { idle, recording, analyzing }

class _VoiceScreenState extends State<VoiceScreen>
    with TickerProviderStateMixin {
  _Mode _mode = _Mode.idle;
  String _transcription = '';
  File? _imageFile;
  bool _isOfflineMode = false;

  // ── Speech to Text ─────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  String _currentLocale = 'fr_FR';

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  late AnimationController _waveCtrl;
  late Animation<double> _wave;

  final TextEditingController _textCtrl = TextEditingController();

  final List<String> _analyzeSteps = [
    '🎤 Traitement de la description...',
    '🧠 Analyse avec Gemma 4...',
    '🔍 Identification du problème...',
    '✅ Diagnostic prêt !',
  ];
  final List<bool> _stepsVisible = [false, false, false, false];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _wave = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _waveCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted && _mode == _Mode.recording) {
            setState(() => _mode = _Mode.idle);
          }
        }
      },
      onError: (error) {
        debugPrint('Speech error: $error');
        if (mounted) {
          setState(() => _mode = _Mode.idle);
          showTaaraSnackbar(context,
              '⚠️ Erreur vocale — essayez de parler plus fort',
              isError: true);
        }
      },
    );

    if (_speechAvailable) {
      final locales = await _speech.locales();
      final frLocale = locales.firstWhere(
        (l) => l.localeId.startsWith('fr'),
        orElse: () => locales.first,
      );
      _currentLocale = frLocale.localeId;
    }

    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      showTaaraSnackbar(
          context, '⚠️ Reconnaissance vocale non disponible',
          isError: true);
      return;
    }

    setState(() {
      _mode = _Mode.recording;
      _transcription = '';
    });

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (mounted) {
          setState(() {
            _transcription = result.recognizedWords;
            if (result.recognizedWords.isNotEmpty) {
              _textCtrl.text = result.recognizedWords;
            }
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      localeId: _currentLocale,
      cancelOnError: false,
      partialResults: true,
      listenMode: ListenMode.dictation,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _mode = _Mode.idle);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null && mounted) {
      setState(() => _imageFile = File(image.path));
      showTaaraSnackbar(context, '📷 Image ajoutée');
    }
  }

  Future<void> _analyze() async {
    final description = _textCtrl.text.trim().isNotEmpty
        ? _textCtrl.text.trim()
        : _transcription;

    if (description.isEmpty && _imageFile == null) {
      showTaaraSnackbar(
          context, '⚠️ Parlez ou décrivez le problème',
          isError: true);
      return;
    }

    if (_speech.isListening) await _speech.stop();

    setState(() {
      _mode = _Mode.analyzing;
      _isOfflineMode = false;
      for (int i = 0; i < _stepsVisible.length; i++) {
        _stepsVisible[i] = false;
      }
    });

    // Vérifie connectivité
    final online = await GemmaService.isOnline();
    if (mounted) setState(() => _isOfflineMode = !online);

    for (int i = 0; i < _analyzeSteps.length - 1; i++) {
      await Future.delayed(Duration(milliseconds: 700 * (i + 1)));
      if (mounted) setState(() => _stepsVisible[i] = true);
    }

    // Appel via le nouveau GemmaService (online → cache → offline)
    DiagnosticResult result;
    try {
      result = await GemmaService.analyzeText(
        description: description,
        image: _imageFile,
      );
    } catch (e) {
      result = DiagnosticResult(
        model: DiagnosticModel.empty(),
        source: DiagnosticSource.error,
      );
    }

    if (mounted) {
      setState(() {
        _stepsVisible[3] = true;
        _mode = _Mode.idle;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      await HistoryService.add(result.model);
      if (mounted) {
        // Passe le DiagnosticResult complet pour que ResultScreen affiche le badge source
        Navigator.pushNamed(context, '/result', arguments: result);
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title:
            Text('Diagnostic vocal', style: GoogleFonts.poppins(fontSize: 16)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: OfflineBadge(isOffline: false)),
          ),
        ],
      ),
      body: _mode == _Mode.analyzing
          ? _buildAnalyzing()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildVoiceSection(),
                  const SizedBox(height: 16),
                  _buildOrDivider(),
                  const SizedBox(height: 16),
                  _buildTextSection(),
                  const SizedBox(height: 16),
                  _buildOrDivider(),
                  const SizedBox(height: 16),
                  _buildImageSection(),
                  const SizedBox(height: 32),
                  _buildAnalyzeButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Décrivez le problème',
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 6),
        Text(
          _speechAvailable
              ? 'Parlez, écrivez, ou ajoutez une image.\nGemma 4 génère un diagnostic complet.'
              : 'Décrivez le problème par écrit ou avec une image.\nGemma 4 génère un diagnostic complet.',
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildVoiceSection() {
    final isRecording = _mode == _Mode.recording;

    return TaaraCard(
      withGoldBorder: isRecording,
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.mic_rounded,
                  color:
                      isRecording ? AppTheme.accent : AppTheme.primary,
                  size: 20),
              const SizedBox(width: 8),
              Text(
                'Enregistrement vocal',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isRecording ? AppTheme.accent : Colors.white),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _speechAvailable
                      ? Colors.greenAccent.withOpacity(0.1)
                      : AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _speechAvailable ? '● PRÊT' : '● INDISPONIBLE',
                  style: TextStyle(
                      color: _speechAvailable
                          ? Colors.greenAccent
                          : AppTheme.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          GestureDetector(
            onTap: _speechAvailable
                ? (isRecording ? _stopListening : _startListening)
                : null,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                return Transform.scale(
                  scale: isRecording ? _pulse.value : 1.0,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: !_speechAvailable
                            ? [Colors.grey.shade700, Colors.grey.shade800]
                            : isRecording
                                ? [AppTheme.accent, const Color(0xFFCC0000)]
                                : [AppTheme.primary, AppTheme.primaryDark],
                      ),
                      boxShadow: _speechAvailable
                          ? [
                              BoxShadow(
                                color: (isRecording
                                        ? AppTheme.accent
                                        : AppTheme.primary)
                                    .withOpacity(0.4),
                                blurRadius: isRecording ? 30 : 15,
                                spreadRadius: isRecording ? 8 : 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          Text(
            !_speechAvailable
                ? 'Non disponible sur cet appareil'
                : isRecording
                    ? '🔴 Écoute en cours... Parlez maintenant'
                    : _transcription.isNotEmpty
                        ? '✅ Transcription terminée'
                        : 'Appuyez pour parler',
            style: TextStyle(
              color: !_speechAvailable
                  ? AppTheme.textSecondary
                  : isRecording
                      ? AppTheme.accent
                      : _transcription.isNotEmpty
                          ? Colors.greenAccent
                          : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          if (isRecording) ...[
            const SizedBox(height: 16),
            _buildWaves(),
          ],

          if (_transcription.isNotEmpty && !isRecording) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Text(
                '"$_transcription"',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.4),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _transcription = '';
                _textCtrl.clear();
              }),
              child: const Text('Réenregistrer',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaves() {
    return AnimatedBuilder(
      animation: _waveCtrl,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(9, (i) {
            final heights = [
              8.0, 16.0, 28.0, 36.0, 44.0, 36.0, 28.0, 16.0, 8.0
            ];
            final factor =
                i % 2 == 0 ? _wave.value : (1 - _wave.value + 0.3);
            return Container(
              width: 4,
              height: heights[i] * factor.clamp(0.3, 1.0),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildTextSection() {
    return TaaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('Description écrite',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _textCtrl,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  'Ex : Mon moteur fait un bruit métallique et chauffe rapidement...',
              hintStyle: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
              filled: true,
              fillColor: AppTheme.surfaceHigh.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: AppTheme.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return TaaraCard(
      withGoldBorder: _imageFile != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.photo_library_outlined,
                  color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('Image (optionnelle)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ajoutez une photo pour enrichir le diagnostic.',
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (_imageFile != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                _imageFile!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.greenAccent, size: 16),
                const SizedBox(width: 6),
                const Text('Image prête',
                    style:
                        TextStyle(color: Colors.greenAccent, fontSize: 12)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _imageFile = null),
                  child: const Text('Supprimer',
                      style: TextStyle(
                          color: AppTheme.accent, fontSize: 12)),
                ),
              ],
            ),
          ] else
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: AppTheme.primary.withOpacity(0.5), size: 32),
                    const SizedBox(height: 8),
                    const Text('Appuyez pour ajouter une image',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.white10)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OU',
              style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.5),
                  fontSize: 11,
                  letterSpacing: 2)),
        ),
        const Expanded(child: Divider(color: Colors.white10)),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    final hasContent = _textCtrl.text.trim().isNotEmpty ||
        _transcription.isNotEmpty ||
        _imageFile != null;

    return GoldButton(
      label: 'ANALYSER AVEC GEMMA 4',
      icon: Icons.psychology_rounded,
      onTap: hasContent ? _analyze : null,
    );
  }

  Widget _buildAnalyzing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.goldGlow,
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: AppTheme.background, size: 40),
            ),
            const SizedBox(height: 28),
            Text(
              'TAARA ANALYSE...',
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 14),
            ),
            if (_isOfflineMode) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.primary.withOpacity(0.3)),
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
            const SizedBox(height: 28),
            for (int i = 0; i < _analyzeSteps.length; i++)
              AnimatedOpacity(
                opacity: _stepsVisible[i] ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_analyzeSteps[i],
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}