import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/services/api_service.dart';

/// Chat client ↔ réparateur lié à un job.
/// Arguments : `{'jobId': String, 'title': String}`.
/// Rafraîchissement par polling (5 s) — simple et robuste sur réseau mobile.
class JobChatScreen extends StatefulWidget {
  const JobChatScreen({super.key});

  @override
  State<JobChatScreen> createState() => _JobChatScreenState();
}

class _JobChatScreenState extends State<JobChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  String? _jobId;
  String _title = 'Discussion';
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_jobId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _jobId = args?['jobId'] as String?;
    _title = (args?['title'] as String?) ?? _title;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final id = _jobId;
    if (id == null) return;
    try {
      final items = await ApiService.messages(id);
      // L'API renvoie les plus récents en premier : on affiche du plus ancien au plus récent.
      items.sort((a, b) => (a['createdAt'] ?? '').compareTo(b['createdAt'] ?? ''));
      final changed = items.length != _messages.length;
      if (!mounted) return;
      setState(() {
        _messages = items;
        _loading = false;
      });
      if (changed) {
        ApiService.markMessagesRead(id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) showTaaraSnackbar(context, e.message, isError: true);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _jobId == null) return;
    setState(() => _sending = true);
    try {
      await ApiService.sendMessage(_jobId!, text);
      _ctrl.clear();
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) showTaaraSnackbar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ApiService.user?.id;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(_title, style: GoogleFonts.poppins(fontSize: 17))),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Aucun message. Dites bonjour 👋',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final m = _messages[i];
                          final mine = m['senderId'] == me;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: mine ? AppTheme.primary : AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (m['imageUrl'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(m['imageUrl'], height: 160, fit: BoxFit.cover),
                                      ),
                                    ),
                                  Text(m['content'] ?? '',
                                      style: TextStyle(color: mine ? AppTheme.background : Colors.white)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Votre message…',
                        hintStyle: const TextStyle(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                    icon: const Icon(Icons.send_rounded, color: AppTheme.background),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
