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
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _buildSOSTip(
                Icons.video_library_outlined, 'Voir un tutoriel vidéo'),
            _buildSOSTip(Icons.forum_outlined, 'Consulter la communauté'),
            _buildSOSTip(
                Icons.contact_support_outlined, 'Contacter un technicien'),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  @override
  Widget build(BuildContext context) {
    final diagnostic = (ModalRoute.of(context)?.settings.arguments
            as DiagnosticModel?) ??
        DiagnosticModel.mock();

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
          // ── Progress header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

          // ── Contenu étape ────────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _stepFade,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Numéro étape géant
                    Text(
                      '${_currentStep + 1}',
                      style: TextStyle(
                        fontSize: 110,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.06),
                        height: 1,
                      ),
                    ),

                    // Titre de l'étape
                    Transform.translate(
                      offset: const Offset(0, -50),
                      child: Text(
                        steps[_currentStep],
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),

                    // Outils nécessaires
                    Transform.translate(
                      offset: const Offset(0, -30),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _getToolsForStep(_currentStep),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Image placeholder (CORRIGÉ — plus de NetworkImage cassé)
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.1)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getIconForStep(_currentStep),
                            color: AppTheme.primary.withOpacity(0.4),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Illustration étape ${_currentStep + 1}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.2),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Conseil expert
                    _buildExpertTip(_currentStep),

                    const SizedBox(height: 100), // Espace pour les boutons
                  ],
                ),
              ),
            ),
          ),

          // ── Navigation bas ───────────────────────────────────────────────
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
                // Bouton précédent
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _goToStep(_currentStep - 1, totalSteps),
                      child: const Text('Précédent'),
                    ),
                  ),

                if (_currentStep > 0) const SizedBox(width: 16),

                // Bouton suivant / terminer
                Expanded(
                  flex: 2,
                  child: GoldButton(
                    label: isLastStep ? 'TERMINER ✓' : 'SUIVANT',
                    icon: isLastStep ? null : Icons.arrow_forward_rounded,
                    onTap: () {
                      if (isLastStep) {
                        Navigator.popUntil(context, NamedRouteHelper.isHome);
                        showTaaraSnackbar(
                            context, '✅ Réparation terminée avec succès !');
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

  List<Widget> _getToolsForStep(int step) {
    const toolsByStep = [
      ['SÉCURITÉ', 'GANTS'],
      ['TOURNEVIS', 'RÉCIPIENT'],
      ['LAMPE', 'LOUPE'],
      ['FER À SOUDER', 'ÉTAIN'],
      ['CONDENSATEUR', 'PINCE'],
      ['FER À SOUDER', 'TEST'],
      ['MULTIMÈTRE', 'BATTERIE'],
    ];
    final tools = step < toolsByStep.length ? toolsByStep[step] : ['OUTILS'];
    return tools
        .map((t) => ToolChip(label: t, icon: Icons.build_outlined))
        .toList();
  }

  IconData _getIconForStep(int step) {
    const icons = [
      Icons.power_off_rounded,
      Icons.home_repair_service_rounded,
      Icons.search_rounded,
      Icons.whatshot_rounded,
      Icons.swap_horiz_rounded,
      Icons.check_rounded,
      Icons.battery_charging_full_rounded,
    ];
    return step < icons.length ? icons[step] : Icons.build_rounded;
  }

  Widget _buildExpertTip(int step) {
    const tips = [
      'Débranchez toujours la batterie en commençant par la borne négative (–) pour éviter tout court-circuit.',
      'Utilisez un récipient magnétique pour ne pas perdre les petites vis pendant le démontage.',
      'Le condensateur gonflé est souvent visible à l\'œil nu — cherchez une déformation du capot supérieur.',
      'Ne dépassez pas 350°C avec le fer à souder pour éviter d\'endommager les pistes du circuit.',
      'Vérifiez la polarité (+/–) avant d\'installer le nouveau condensateur. Une erreur peut l\'endommager.',
      'Attendez que les soudures refroidissent 30 secondes avant de manipuler la carte.',
      'Testez sous charge progressivement — démarrez d\'abord sans connecter les gros consommateurs.',
    ];
    final tip = step < tips.length ? tips[step] : 'Prenez votre temps et vérifiez chaque connexion.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              color: AppTheme.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white70, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper pour la navigation
class NamedRouteHelper {
  static bool isHome(Route<dynamic> route) => route.settings.name == '/home';
}