import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/services/api_service.dart';

/// Suivi des demandes (client) et des interventions (pro).
class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  @override
  Widget build(BuildContext context) {
    if (!ApiService.isLoggedIn) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: Text('Mes demandes', style: GoogleFonts.poppins(fontSize: 17))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: GoldButton(
              label: 'SE CONNECTER',
              icon: Icons.login_rounded,
              onTap: () async {
                final ok = await Navigator.pushNamed(context, '/auth');
                if (ok == true && mounted) setState(() {});
              },
            ),
          ),
        ),
      );
    }

    final isPro = ApiService.user?.isPro ?? false;
    if (!isPro) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: Text('Mes demandes', style: GoogleFonts.poppins(fontSize: 17))),
        body: const _JobList(asPro: false),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text('Mes jobs', style: GoogleFonts.poppins(fontSize: 17)),
          bottom: const TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [Tab(text: 'INTERVENTIONS'), Tab(text: 'MES DEMANDES')],
          ),
        ),
        body: const TabBarView(children: [_JobList(asPro: true), _JobList(asPro: false)]),
      ),
    );
  }
}

class _JobList extends StatefulWidget {
  final bool asPro;
  const _JobList({required this.asPro});

  @override
  State<_JobList> createState() => _JobListState();
}

class _JobListState extends State<_JobList> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _jobs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = widget.asPro ? await ApiService.myAssignedJobs() : await ApiService.myRequests();
      if (mounted) setState(() => _jobs = jobs);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) showTaaraSnackbar(context, success);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showTaaraSnackbar(context, e.message, isError: true);
    }
  }

  Future<double?> _askPrice(String title, double initial) async {
    final ctrl = TextEditingController(text: initial > 0 ? initial.toStringAsFixed(0) : '');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(suffixText: 'FCFA'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.replaceAll(' ', ''))),
            child: const Text('Valider', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _rate(String jobId) async {
    int score = 5;
    final commentCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Noter l\'intervention', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setLocal(() => score = i),
                      icon: Icon(i <= score ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: AppTheme.primary, size: 30),
                    ),
                ],
              ),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Commentaire (optionnel)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Envoyer', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    );
    final comment = commentCtrl.text;
    commentCtrl.dispose();
    if (ok == true) {
      await _run(() => ApiService.rateJob(jobId, score, comment: comment), 'Merci pour votre note ✓');
    }
  }

  Future<bool> _confirm(String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  List<Widget> _actions(Map<String, dynamic> job) {
    final id = job['id'] as String;
    final status = job['status'] as String? ?? 'PENDING';
    final quoted = (job['quotedPrice'] ?? 0).toDouble();
    final actions = <Widget>[];

    void add(String label, IconData icon, VoidCallback onTap, {Color color = AppTheme.primary}) {
      actions.add(TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ));
    }

    if (status != 'CANCELLED') {
      add('Discuter', Icons.chat_bubble_outline, () {
        Navigator.pushNamed(context, '/chat', arguments: {'jobId': id, 'title': _counterpart(job)});
      }, color: Colors.white70);
    }

    if (widget.asPro) {
      if (status == 'PENDING') {
        add('Accepter', Icons.check_circle_outline, () async {
          final price = await _askPrice('Votre prix', quoted);
          if (price != null) await _run(() => ApiService.acceptJob(id, price), 'Job accepté ✓');
        });
        add('Refuser', Icons.close_rounded, () async {
          if (await _confirm('Refuser cette demande ?')) {
            await _run(() => ApiService.declineJob(id), 'Demande refusée');
          }
        }, color: AppTheme.accent);
      } else if (status == 'ACCEPTED') {
        add('Démarrer', Icons.play_arrow_rounded, () => _run(() => ApiService.startJob(id), 'Intervention démarrée'));
      }
      if (status == 'ACCEPTED' || status == 'IN_PROGRESS') {
        add('Terminer', Icons.task_alt_rounded, () async {
          final price = await _askPrice('Prix final', quoted);
          if (price != null) await _run(() => ApiService.completeJob(id, price), 'Job clôturé ✓');
        });
      }
    } else {
      if (status == 'PENDING' || status == 'ACCEPTED' || status == 'IN_PROGRESS') {
        add('Annuler', Icons.cancel_outlined, () async {
          if (await _confirm('Annuler cette demande ?')) {
            await _run(() => ApiService.cancelJob(id), 'Demande annulée');
          }
        }, color: AppTheme.accent);
      }
      if (status == 'COMPLETED') {
        final paid = (job['payments'] as List? ?? []).isNotEmpty;
        if (!paid) {
          add('Payé en espèces', Icons.payments_outlined, () async {
            if (await _confirm('Confirmer que vous avez payé ce réparateur en espèces ?')) {
              await _run(() => ApiService.payCash(id), 'Paiement enregistré ✓');
            }
          });
        }
        if (job['rating'] == null) add('Noter', Icons.star_outline_rounded, () => _rate(id));
      }
    }
    return actions;
  }

  String _counterpart(Map<String, dynamic> job) {
    final Map<String, dynamic> parent = Map<String, dynamic>.from(
        (widget.asPro ? job['jobRequest'] : job['professional']) ?? {});
    final person = parent[widget.asPro ? 'client' : 'user'] as Map?;
    if (person == null) return 'Job';
    return '${person['firstName'] ?? ''} ${person['lastName'] ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null || _jobs.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(_error != null ? Icons.wifi_off_rounded : Icons.inbox_outlined,
                color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text(
              _error ??
                  (widget.asPro
                      ? 'Aucune intervention pour le moment.'
                      : 'Aucune demande. Faites un diagnostic puis « Trouver un réparateur ».'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _jobs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final job = _jobs[i];
          final diag = Map<String, dynamic>.from(job['diagnostic'] ?? {});
          final price = (job['actualPrice'] ?? job['quotedPrice'] ?? 0).toDouble();
          final created = DateTime.tryParse(job['createdAt'] ?? '');
          final rating = job['rating'] as Map?;
          return TaaraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(diag['problemType'] ?? 'Intervention',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    _StatusPill(status: job['status'] ?? 'PENDING'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.asPro ? 'Client' : 'Réparateur'} : ${_counterpart(job)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                if ((job['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(job['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${price.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    if (rating != null) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.star_rounded, color: AppTheme.primary, size: 14),
                      Text('${rating['score']}/5', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                    const Spacer(),
                    if (created != null)
                      Text(
                        '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                  ],
                ),
                Wrap(spacing: 4, children: _actions(job)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  static const _labels = {
    'PENDING': ('En attente', Color(0xFF8A9BB5)),
    'ACCEPTED': ('Acceptée', AppTheme.primary),
    'IN_PROGRESS': ('En cours', Colors.lightBlueAccent),
    'COMPLETED': ('Terminée', Colors.greenAccent),
    'CANCELLED': ('Annulée', AppTheme.accent),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labels[status] ?? (status, AppTheme.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
