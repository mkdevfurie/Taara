import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/models/diagnostic_model.dart';
import 'package:taara/services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<DiagnosticModel> _history = [];
  bool _loading = true;
  String _filter = 'TOUS'; // TOUS | CRITIQUE | ATTENTION | BON ÉTAT

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final data = await HistoryService.load();
    if (mounted) setState(() { _history = data; _loading = false; });
  }

  Future<void> _deleteItem(int index) async {
    await HistoryService.remove(index);
    await _loadHistory();
    if (mounted) showTaaraSnackbar(context, 'Diagnostic supprimé');
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Effacer l\'historique',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tous les diagnostics seront supprimés définitivement.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('EFFACER',
                style: TextStyle(
                    color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await HistoryService.clear();
      await _loadHistory();
      if (mounted) showTaaraSnackbar(context, 'Historique effacé');
    }
  }

  List<DiagnosticModel> get _filtered {
    if (_filter == 'TOUS') return _history;
    return _history.where((d) => d.status == _filter).toList();
  }

  IconData _iconForObject(String name) {
    final n = name.toLowerCase();
    if (n.contains('moteur') || n.contains('alternateur') || n.contains('motor'))
      return Icons.electric_bolt;
    if (n.contains('pompe') || n.contains('pump')) return Icons.water_drop_outlined;
    if (n.contains('carte') || n.contains('circuit') || n.contains('board'))
      return Icons.developer_board;
    if (n.contains('batterie') || n.contains('battery'))
      return Icons.battery_charging_full;
    if (n.contains('téléphone') || n.contains('phone')) return Icons.phone_android;
    if (n.contains('ordinateur') || n.contains('laptop')) return Icons.computer;
    if (n.contains('ventilateur') || n.contains('fan')) return Icons.air;
    return Icons.build_circle_outlined;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Historique',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: AppTheme.accent),
              tooltip: 'Tout effacer',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _history.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildFilterBar(),
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildFilterEmpty()
                          : RefreshIndicator(
                              onRefresh: _loadHistory,
                              color: AppTheme.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final d = filtered[index];
                                  final realIndex = _history.indexOf(d);
                                  return _buildHistoryItem(d, realIndex, index);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['TOUS', 'CRITIQUE', 'ATTENTION', 'BON ÉTAT'];
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filters[i];
          final active = _filter == f;
          Color color = AppTheme.primary;
          if (f == 'CRITIQUE') color = AppTheme.accent;
          if (f == 'BON ÉTAT') color = Colors.greenAccent;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? color.withOpacity(0.15) : AppTheme.surfaceLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? color.withOpacity(0.6) : Colors.white12),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      active ? FontWeight.bold : FontWeight.normal,
                  color: active ? color : AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(DiagnosticModel d, int realIndex, int displayIndex) {
    return Dismissible(
      key: Key('history_$realIndex'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: AppTheme.accent),
      ),
      onDismissed: (_) => _deleteItem(realIndex),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TaaraCard(
          onTap: () => Navigator.pushNamed(context, '/result', arguments: d),
          child: Row(
            children: [
              // Icône objet
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.15)),
                ),
                child: Icon(_iconForObject(d.objectName),
                    color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.objectName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.problem,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 10, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(d.analyzedAt),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(d.confidence * 100).toInt()}%',
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Badge statut
              Column(
                children: [
                  StatusBadge(status: d.status),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right,
                      color: AppTheme.textSecondary, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded,
                color: AppTheme.primary.withOpacity(0.25), size: 72),
            const SizedBox(height: 24),
            Text(
              'Aucun diagnostic encore',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Vos diagnostics apparaîtront ici après\nchaque analyse avec Taara.',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GoldButton(
              label: 'LANCER UN DIAGNOSTIC',
              icon: Icons.camera_alt_rounded,
              onTap: () => Navigator.pushNamed(context, '/scan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off,
              color: AppTheme.primary.withOpacity(0.3), size: 48),
          const SizedBox(height: 16),
          Text(
            'Aucun diagnostic "$_filter"',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}