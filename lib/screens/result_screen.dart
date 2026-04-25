import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/models/diagnostic_model.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showThinking = false;

  // ✅ Icône dynamique selon l'objet réel identifié par Gemma 4
  IconData _getObjectIcon(String objectName) {
    final name = objectName.toLowerCase();
    if (name.contains('moteur') || name.contains('alternateur') ||
        name.contains('motor')) return Icons.electric_bolt;
    if (name.contains('pompe') || name.contains('pump'))
      return Icons.water_drop_outlined;
    if (name.contains('carte') || name.contains('circuit') ||
        name.contains('électronique') || name.contains('board'))
      return Icons.developer_board;
    if (name.contains('moniteur') || name.contains('écran') ||
        name.contains('monitor')) return Icons.monitor;
    if (name.contains('batterie') || name.contains('battery'))
      return Icons.battery_charging_full;
    if (name.contains('téléphone') || name.contains('phone') ||
        name.contains('mobile')) return Icons.phone_android;
    if (name.contains('ventilateur') || name.contains('fan')) return Icons.air;
    if (name.contains('câble') || name.contains('cable')) return Icons.cable;
    if (name.contains('chargeur') || name.contains('charger'))
      return Icons.charging_station;
    if (name.contains('ordinateur') || name.contains('computer') ||
        name.contains('laptop')) return Icons.computer;
    return Icons.build_circle_outlined;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Résultat réel — pas de mock forcé
    final diagnostic =
        ModalRoute.of(context)?.settings.arguments as DiagnosticModel?;

    if (diagnostic == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Diagnostic')),
        body: const Center(
          child: Text('Aucun diagnostic disponible.',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Diagnostic Taara',
            style: GoogleFonts.poppins(fontSize: 17)),
        actions: [
          IconButton(
            onPressed: () =>
                showTaaraSnackbar(context, 'Partage à venir...'),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(diagnostic),
            const SizedBox(height: 20),
            _buildConfidenceBar(diagnostic.confidence),
            const SizedBox(height: 20),
            _buildDiagnosticCard(diagnostic),
            const SizedBox(height: 16),
            _buildThinkingCard(diagnostic),
            const SizedBox(height: 16),
            if (diagnostic.parts.isNotEmpty) _buildPartsCard(diagnostic),
            const SizedBox(height: 28),
            GoldButton(
              label: 'COMMENCER LA RÉPARATION',
              icon: Icons.build_rounded,
              onTap: () => Navigator.pushNamed(context, '/guide',
                  arguments: diagnostic),
            ),
            const SizedBox(height: 20),
            _buildSafetyWarning(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DiagnosticModel d) {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Icon(_getObjectIcon(d.objectName),
              color: AppTheme.primary, size: 36),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.objectName,
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${(d.confidence * 100).toInt()}% de confiance',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13),
                  ),
                  const SizedBox(width: 10),
                  StatusBadge(status: d.status),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceBar(double confidence) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Niveau de confiance',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            Text('${(confidence * 100).toInt()}%',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: confidence,
            backgroundColor: AppTheme.surfaceHigh,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticCard(DiagnosticModel d) {
    return TaaraCard(
      withGoldBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined,
                  color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text('Diagnostic IA',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Text(d.problem,
              style: const TextStyle(
                  color: Colors.white70, height: 1.5, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildThinkingCard(DiagnosticModel d) {
    return TaaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () =>
                setState(() => _showThinking = !_showThinking),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.psychology_outlined,
                        color: AppTheme.textSecondary, size: 18),
                    SizedBox(width: 8),
                    Text('Raisonnement IA',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Icon(
                  _showThinking
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          if (_showThinking && d.thinking.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            for (final line in d.thinking)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right,
                        color: AppTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(line,
                          style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              height: 1.4)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartsCard(DiagnosticModel d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PIÈCES CONCERNÉES',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: AppTheme.textSecondary,
              letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        for (final part in d.parts) ...[
          TaaraCard(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.settings_outlined,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(part,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500))),
                const Icon(Icons.arrow_forward_ios,
                    color: AppTheme.textSecondary, size: 12),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildSafetyWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AppTheme.accent, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Toujours consulter un professionnel pour les réparations critiques. "
              "Coupez l'alimentation avant toute intervention.",
              style: TextStyle(
                  color: AppTheme.accent, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}