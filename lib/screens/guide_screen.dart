import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/models/diagnostic_model.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _stepAnim;
  late Animation<double> _stepFade;

  @override
  void initState() {
    super.initState();
    _stepAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _stepFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _stepAnim, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _stepAnim.dispose();
    super.dispose();
  }

  Future<void> _goToStep(int index, int totalSteps) async {
    if (index < 0 || index >= totalSteps) return;
    await _stepAnim.reverse();
    setState(() => _currentStep = index);
    _stepAnim.forward();
  }

  void _showSOSSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vous êtes bloqué ?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
              'Voici quelques suggestions pour débloquer cette étape.',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _buildSOSTip(
                Icons.video_library_outlined, 'Voir un tutoriel vidéo'),
            _buildSOSTip(
                Icons.forum_outlined, 'Consulter la communauté'),
            _buildSOSTip(Icons.contact_support_outlined,
                'Contacter un technicien'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSTip(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TaaraCard(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 14),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                color: AppTheme.textSecondary, size: 12),
          ],
        ),
      ),
    );
  }

  // ✅ Outils détectés dynamiquement depuis le texte de l'étape réelle
  List<Widget> _getToolsForStep(String stepText) {
    final text = stepText.toLowerCase();
    final List<String> tools = [];

    if (text.contains('tournevis') || text.contains('vis') ||
        text.contains('dévisser')) tools.add('TOURNEVIS');
    if (text.contains('souder') || text.contains('soudure') ||
        text.contains('fer')) tools.add('FER À SOUDER');
    if (text.contains('multimètre') || text.contains('tester') ||
        text.contains('mesure')) tools.add('MULTIMÈTRE');
    if (text.contains('pince')) tools.add('PINCE');
    if (text.contains('gant') || text.contains('protection') ||
        text.contains('sécurité')) tools.add('GANTS');
    if (text.contains('batterie') || text.contains('alimentation') ||
        text.contains('débranch')) tools.add('SÉCURITÉ');
    if (text.contains('clé') || text.contains('écrou')) tools.add('CLÉ');
    if (text.contains('chiffon') || text.contains('nettoy')) tools.add('CHIFFON');
    if (text.contains('lampe') || text.contains('lumière')) tools.add('LAMPE');

    if (tools.isEmpty) tools.add('OUTILS');

    return tools
        .map((t) => ToolChip(label: t, icon: Icons.build_outlined))
        .toList();
  }

  // ✅ Conseil générique basé sur position de l'étape
  String _getTipForStep(int step, int total) {
    if (step == 0) {
      return "Avant de commencer, assurez-vous d'avoir tous les outils nécessaires et de travailler dans un espace bien éclairé.";
    }
    if (step == total - 1) {
      return "Dernière étape ! Vérifiez soigneusement chaque connexion avant de remettre sous tension.";
    }
    if (step == 1) {
      return "Prenez des photos de chaque étape de démontage pour faciliter le remontage.";
    }
    return "Prenez votre temps et vérifiez chaque connexion avant de passer à l'étape suivante.";
  }

  // ✅ Icône basée sur le texte de l'étape
  IconData _getIconForStep(String stepText) {
    final text = stepText.toLowerCase();
    if (text.contains('couper') || text.contains('débranch') ||
        text.contains('alimentation')) return Icons.power_off_rounded;
    if (text.contains('démonter') || text.contains('dévisser') ||
        text.contains('ouvrir')) return Icons.home_repair_service_rounded;
    if (text.contains('inspecter') || text.contains('vérifier') ||
        text.contains('observer')) return Icons.search_rounded;
    if (text.contains('souder') || text.contains('chaleur') ||
        text.contains('fer')) return Icons.whatshot_rounded;
    if (text.contains('remplacer') || text.contains('installer') ||
        text.contains('nouveau')) return Icons.swap_horiz_rounded;
    if (text.contains('tester') || text.contains('vérif') ||
        text.contains('mesure')) return Icons.check_rounded;
    if (text.contains('nettoyer') || text.contains('nettoy')) return Icons.cleaning_services;
    if (text.contains('brancher') || text.contains('connecter') ||
        text.contains('rebranch')) return Icons.battery_charging_full_rounded;
    return Icons.build_rounded;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Utilise le diagnostic réel de Gemma 4
    final diagnostic =
        ModalRoute.of(context)?.settings.arguments as DiagnosticModel?;

    if (diagnostic == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Guide')),
        body: const Center(
          child: Text('Aucun guide disponible.',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final steps = diagnostic.steps;
    final totalSteps = steps.length;
    final isLastStep = _currentStep == totalSteps - 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          diagnostic.objectName,
          style: GoogleFonts.poppins(fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSOSSheet(context),
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.help_outline_rounded, size: 18),
        label: const Text('SOS',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // ── Progress ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Étape ${_currentStep + 1} / $totalSteps',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    Text(
                      '${((_currentStep + 1) / totalSteps * 100).toInt()}% complété',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / totalSteps,
                    backgroundColor: AppTheme.surfaceHigh,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // ── Contenu ───────────────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _stepFade,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Numéro géant décoratif
                    Text(
                      '${_currentStep + 1}',
                      style: TextStyle(
                        fontSize: 110,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.06),
                        height: 1,
                      ),
                    ),

                    // ✅ Texte réel de l'étape Gemma 4
                    Transform.translate(
                      offset: const Offset(0, -50),
                      child: Text(
                        steps[_currentStep],
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),

                    // ✅ Outils détectés dynamiquement
                    Transform.translate(
                      offset: const Offset(0, -30),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _getToolsForStep(steps[_currentStep]),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Illustration avec icône dynamique
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                AppTheme.primary.withOpacity(0.1)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getIconForStep(steps[_currentStep]),
                            color: AppTheme.primary.withOpacity(0.4),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Étape ${_currentStep + 1} sur $totalSteps',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.2),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ Conseil contextuel
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded,
                              color: AppTheme.primary, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getTipForStep(_currentStep, totalSteps),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),

          // ── Navigation ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: AppTheme.background,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _goToStep(_currentStep - 1, totalSteps),
                      child: const Text('Précédent'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: GoldButton(
                    label: isLastStep ? 'TERMINER ✓' : 'SUIVANT',
                    icon: isLastStep
                        ? null
                        : Icons.arrow_forward_rounded,
                    onTap: () {
                      if (isLastStep) {
                        // Retour propre vers l'accueil en vidant la stack
                        Navigator.of(context).popUntil((route) => route.settings.name == '/home');
                      } else {
                        _goToStep(_currentStep + 1, totalSteps);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NamedRouteHelper {
  static bool isHome(Route<dynamic> route) =>
      route.settings.name == '/home';
}