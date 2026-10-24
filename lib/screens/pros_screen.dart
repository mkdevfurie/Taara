import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/models/diagnostic_model.dart';
import 'package:taara/services/api_service.dart';

/// Recherche d'un réparateur et envoi d'une demande d'intervention.
/// Argument de route optionnel : le [DiagnosticModel] à transmettre au pro.
class ProsScreen extends StatefulWidget {
  const ProsScreen({super.key});

  @override
  State<ProsScreen> createState() => _ProsScreenState();
}

class _ProsScreenState extends State<ProsScreen> {
  static const _specialties = [
    'Électricien',
    'Mécanicien',
    'Plombier',
    'Électronicien',
    'Frigoriste',
  ];

  final _zoneCtrl = TextEditingController();
  String? _specialty;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pros = [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _zoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pros = await ApiService.searchProfessionals(
        specialty: _specialty,
        zone: _zoneCtrl.text.trim(),
      );
      if (mounted) setState(() => _pros = pros);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(Map<String, dynamic> pro, DiagnosticModel? diagnostic) async {
    if (!ApiService.isLoggedIn) {
      final ok = await Navigator.pushNamed(context, '/auth');
      if (ok != true || !mounted) return;
    }
    if (diagnostic == null) {
      showTaaraSnackbar(context, 'Faites d\'abord un diagnostic (scan ou voix)', isError: true);
      return;
    }
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RequestSheet(pro: pro, diagnostic: diagnostic),
    );
    if (sent == true && mounted) {
      showTaaraSnackbar(context, 'Demande envoyée ✓ Le réparateur va vous répondre.');
      Navigator.pushReplacementNamed(context, '/my-jobs');
    }
  }

  @override
  Widget build(BuildContext context) {
    final diagnostic = ModalRoute.of(context)?.settings.arguments as DiagnosticModel?;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Trouver un réparateur', style: GoogleFonts.poppins(fontSize: 17)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (diagnostic != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TaaraCard(
                withGoldBorder: true,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_outlined, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${diagnostic.objectName} — ${diagnostic.problem}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _zoneCtrl,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Ville (ex : Lomé)',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.place_outlined, color: AppTheme.textSecondary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: AppTheme.primary),
                  onPressed: _search,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                _chip('Tous', _specialty == null, () => _specialty = null),
                for (final s in _specialties) _chip(s, _specialty == s, () => _specialty = s),
              ],
            ),
          ),
          Expanded(child: _buildList(diagnostic)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback select) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(select);
          _search();
        },
        selectedColor: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        labelStyle: TextStyle(
          color: selected ? AppTheme.background : Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        side: BorderSide.none,
        showCheckmark: false,
      ),
    );
  }

  Widget _buildList(DiagnosticModel? diagnostic) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null) {
      return _EmptyState(icon: Icons.wifi_off_rounded, message: _error!, onRetry: _search);
    }
    if (_pros.isEmpty) {
      return _EmptyState(
        icon: Icons.person_search_outlined,
        message: 'Aucun réparateur vérifié trouvé pour ces critères.',
        onRetry: _search,
      );
    }
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _search,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: _pros.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ProCard(pro: _pros[i], onRequest: () => _request(_pros[i], diagnostic)),
      ),
    );
  }
}

class _ProCard extends StatelessWidget {
  final Map<String, dynamic> pro;
  final VoidCallback onRequest;

  const _ProCard({required this.pro, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(pro['user'] ?? {});
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final specialties = List<String>.from(pro['specialties'] ?? []);
    final zones = List<String>.from(pro['serviceZone'] ?? []);
    final rating = (pro['rating'] ?? 0).toDouble();
    final rate = (pro['hourlyRate'] ?? 0).toDouble();

    return TaaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primary.withOpacity(0.15),
                backgroundImage:
                    user['profileImage'] != null ? NetworkImage(user['profileImage']) : null,
                child: user['profileImage'] == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                        if (pro['isVerified'] == true) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: AppTheme.primary, size: 16),
                        ],
                      ],
                    ),
                    Text(specialties.join(' · '),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(children: [
                    const Icon(Icons.star_rounded, color: AppTheme.primary, size: 16),
                    Text(rating > 0 ? rating.toStringAsFixed(1) : '—',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                  Text('${pro['totalJobs'] ?? 0} jobs',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
          if ((pro['bio'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(pro['bio'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.place_outlined, color: AppTheme.textSecondary, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(zones.isEmpty ? 'Zone non précisée' : zones.join(', '),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
              if (rate > 0)
                Text('${rate.toStringAsFixed(0)} FCFA/h',
                    style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.send_rounded, size: 18, color: AppTheme.primary),
              label: const Text('DEMANDER UNE INTERVENTION'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formulaire : prix estimé + précisions, puis création diagnostic + job.
class _RequestSheet extends StatefulWidget {
  final Map<String, dynamic> pro;
  final DiagnosticModel diagnostic;

  const _RequestSheet({required this.pro, required this.diagnostic});

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _priceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final price = double.tryParse(_priceCtrl.text.replaceAll(' ', ''));
    if (price == null || price < 0) {
      showTaaraSnackbar(context, 'Indiquez un budget estimé en FCFA', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      final diagnosticId = await ApiService.uploadDiagnostic(widget.diagnostic);
      await ApiService.createJob(
        diagnosticId: diagnosticId,
        professionalId: widget.pro['id'],
        estimatedPrice: price,
        description: _noteCtrl.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showTaaraSnackbar(context, e.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(widget.pro['user'] ?? {});
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Demande à ${user['firstName'] ?? 'ce réparateur'}',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            'Le diagnostic Taara est joint à votre demande. Le réparateur propose ensuite son prix.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration('Budget estimé (FCFA)', Icons.payments_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            maxLength: 2000,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration('Précisions (adresse, disponibilités…)', Icons.notes_rounded),
          ),
          const SizedBox(height: 12),
          _sending
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : GoldButton(label: 'ENVOYER LA DEMANDE', icon: Icons.send_rounded, onTap: _send),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  const _EmptyState({required this.icon, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Réessayer', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
