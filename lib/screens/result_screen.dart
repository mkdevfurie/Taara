import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/models/diagnostic_model.dart';
import 'package:taara/services/gemma_service.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showThinking = false;

  // ── Icône dynamique selon l'objet identifié par Gemma 4 ──────────────────
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

  // ── Ouvre la recherche d'une pièce sur AliExpress / Google Shopping ──────
  Future<void> _orderPart(String partName, String? searchTerm) async {
    final query = Uri.encodeComponent(searchTerm?.isNotEmpty == true
        ? searchTerm!
        : partName);

    // Affiche un choix de marketplaces
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _buildOrderSheet(partName, query),
    );
  }

  Widget _buildOrderSheet(String partName, String query) {
    final marketplaces = [
      {
        'name': 'Google Shopping',
        'icon': Icons.search_rounded,
        'url': 'https://www.google.com/search?q=$query&tbm=shop',
        'color': AppTheme.primary,
      },
      {
        'name': 'AliExpress',
        'icon': Icons.shopping_cart_outlined,
        'url': 'https://www.aliexpress.com/wholesale?SearchText=$query',
        'color': const Color(0xFFE8401C),
      },
      {
        'name': 'Amazon',
        'icon': Icons.store_outlined,
        'url': 'https://www.amazon.fr/s?k=$query',
        'color': const Color(0xFFFF9900),
      },
      {
        'name': 'eBay',
        'icon': Icons.sell_outlined,
        'url': 'https://www.ebay.fr/sch/i.html?_nkw=$query',
        'color': const Color(0xFF86B817),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Commander : $partName',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Choisissez où chercher cette pièce :',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ...marketplaces.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    final uri = Uri.parse(m['url'] as String);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } else {
                      if (mounted) {
                        showTaaraSnackbar(context,
                            '⚠️ Impossible d\'ouvrir ${m['name']}',
                            isError: true);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: (m['color'] as Color).withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(m['icon'] as IconData,
                            color: m['color'] as Color, size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            m['name'] as String,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 15),
                          ),
                        ),
                        const Icon(Icons.open_in_new_rounded,
                            color: AppTheme.textSecondary, size: 16),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    // Supporte DiagnosticModel seul OU DiagnosticResult (avec source)
    final DiagnosticModel? diagnostic;
    final DiagnosticSource? source;

    if (args is DiagnosticResult) {
      diagnostic = args.model;
      source = args.source;
    } else if (args is DiagnosticModel) {
      diagnostic = args;
      source = null;
    } else {
      diagnostic = null;
      source = null;
    }

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
        title:
            Text('Diagnostic Taara', style: GoogleFonts.poppins(fontSize: 17)),
        actions: [
          // Badge source (online / offline / cache)
          if (source != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: _SourceBadge(source: source)),
            ),
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
            // Bannière offline si résultat depuis cache
            if (source == DiagnosticSource.offline)
              _buildOfflineBanner(isCached: true),
            if (source == DiagnosticSource.offlineEmpty)
              _buildOfflineBanner(isCached: false),

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
              onTap: () =>
                  Navigator.pushNamed(context, '/guide', arguments: diagnostic),
            ),
            const SizedBox(height: 20),
            _buildSafetyWarning(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Bannière mode offline ─────────────────────────────────────────────────
  Widget _buildOfflineBanner({required bool isCached}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCached
            ? AppTheme.primary.withOpacity(0.08)
            : AppTheme.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCached
              ? AppTheme.primary.withOpacity(0.3)
              : AppTheme.accent.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCached ? Icons.offline_bolt_rounded : Icons.wifi_off_rounded,
            color: isCached ? AppTheme.primary : AppTheme.accent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isCached
                  ? 'Mode hors-ligne — résultat issu du cache local Taara'
                  : 'Hors-ligne et aucun cache disponible. Connectez-vous pour analyser.',
              style: TextStyle(
                color: isCached ? AppTheme.primary : AppTheme.accent,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
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
                    color: AppTheme.primary, fontWeight: FontWeight.bold)),
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
                  _showThinking ? Icons.expand_less : Icons.expand_more,
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

  // ── Carte pièces avec bouton Commander ────────────────────────────────────
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
        for (int i = 0; i < d.parts.length; i++) ...[
          TaaraCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.settings_outlined,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(d.parts[i],
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14)),
                ),
                const SizedBox(width: 8),
                // ── Bouton Commander ──────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    final searchTerm = i < d.searchTerms.length
                        ? d.searchTerms[i]
                        : null;
                    _orderPart(d.parts[i], searchTerm);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 13, color: AppTheme.background),
                        SizedBox(width: 5),
                        Text(
                          'Commander',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.background,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
              style:
                  TextStyle(color: AppTheme.accent, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge source du diagnostic ────────────────────────────────────────────────
class _SourceBadge extends StatelessWidget {
  final DiagnosticSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isOnline = source == DiagnosticSource.online;
    final color = isOnline ? Colors.greenAccent : AppTheme.primary;
    final label = isOnline ? 'En ligne' : 'Hors-ligne';
    final icon = isOnline ? Icons.cloud_done_outlined : Icons.offline_bolt_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}