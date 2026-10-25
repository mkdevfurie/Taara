import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/services/api_service.dart';
import 'package:taara/services/realtime_service.dart';

/// Chat client ↔ réparateur lié à un job.
/// Arguments : `{'jobId': String, 'title': String}`.
/// Messages reçus en direct (Socket.IO) ; un rechargement toutes les 30 s
/// sert de filet de sécurité si la connexion temps réel tombe.
class JobChatScreen extends StatefulWidget {
  const JobChatScreen({super.key});

  @override
  State<JobChatScreen> createState() => _JobChatScreenState();
}

class _JobChatScreenState extends State<JobChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  Timer? _typingTimer;
  StreamSubscription<Map<String, dynamic>>? _msgSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  bool _otherTyping = false;
  bool _iAmTyping = false;
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
    final id = _jobId;
    if (id != null) {
      RealtimeService.joinJob(id);
      _msgSub = RealtimeService.messages
          .where((m) => m['jobId'] == id)
          .listen(_onLiveMessage);
      _typingSub = RealtimeService.typing
          .where((t) => t['userId'] != ApiService.user?.id)
          .listen((t) {
        if (mounted) setState(() => _otherTyping = t['typing'] == true);
      });
    }
    _timer =
        Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  void _onLiveMessage(Map<String, dynamic> m) {
    if (!mounted || _messages.any((x) => x['id'] == m['id'])) return;
    setState(() {
      _messages = [..._messages, m];
      _otherTyping = false;
    });
    ApiService.markMessagesRead(_jobId!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _onTextChanged(String text) {
    final id = _jobId;
    if (id == null) return;
    if (!_iAmTyping && text.isNotEmpty) {
      _iAmTyping = true;
      RealtimeService.sendTyping(id, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _iAmTyping = false;
      RealtimeService.sendTyping(id, false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _typingTimer?.cancel();
    _msgSub?.cancel();
    _typingSub?.cancel();
    if (_jobId != null) {
      if (_iAmTyping) RealtimeService.sendTyping(_jobId!, false);
      RealtimeService.leaveJob(_jobId!);
    }
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
      items.sort(
          (a, b) => (a['createdAt'] ?? '').compareTo(b['createdAt'] ?? ''));
      final changed = items.length != _messages.length;
      if (!mounted) return;
      setState(() {
        _messages = items;
        _loading = false;
      });
      if (changed) {
        ApiService.markMessagesRead(id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients)
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
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
      _typingTimer?.cancel();
      if (_iAmTyping) {
        _iAmTyping = false;
        RealtimeService.sendTyping(_jobId!, false);
      }
      // Le message revient aussi par le temps réel ; ce rechargement couvre le mode dégradé
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, style: GoogleFonts.poppins(fontSize: 17)),
            ValueListenableBuilder<bool>(
              valueListenable: RealtimeService.connected,
              builder: (_, live, __) => Text(
                _otherTyping ? 'écrit…' : (live ? 'en direct' : 'reconnexion…'),
                style: TextStyle(
                  fontSize: 11,
                  color: _otherTyping || live
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
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
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color:
                                    mine ? AppTheme.primary : AppTheme.surface,
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
                                        child: Image.network(m['imageUrl'],
                                            height: 160, fit: BoxFit.cover),
                                      ),
                                    ),
                                  Text(m['content'] ?? '',
                                      style: TextStyle(
                                          color: mine
                                              ? AppTheme.background
                                              : Colors.white)),
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
                      onChanged: _onTextChanged,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Votre message…',
                        hintStyle:
                            const TextStyle(color: AppTheme.textSecondary),
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
                    style:
                        IconButton.styleFrom(backgroundColor: AppTheme.primary),
                    icon: const Icon(Icons.send_rounded,
                        color: AppTheme.background),
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
