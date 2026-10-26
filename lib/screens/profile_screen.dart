import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:taara/config/env.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/services/history_service.dart';
import 'package:taara/services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _profileKey = 'taara_profile';

  // Profil local (sans compte) : nom, métier, ville gardés sur le téléphone
  String _name = '';
  String _job = '';
  String _city = '';
  bool _editing = false;
  bool _saving = false;
  bool _loading = true;
  Map<String, int> _stats = {};

  // Compte connecté : données du serveur
  Map<String, dynamic>? _account;

  late TextEditingController _nameCtrl;
  late TextEditingController _jobCtrl;
  late TextEditingController _cityCtrl;
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _jobCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    ApiService.currentUser.addListener(_onSessionChanged);
    _loadData();
  }

  @override
  void dispose() {
    ApiService.currentUser.removeListener(_onSessionChanged);
    _nameCtrl.dispose();
    _jobCtrl.dispose();
    _cityCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() => _editing = false);
    _loadData();
  }

  bool get _loggedIn => ApiService.isLoggedIn;

  /// Nom affiché : celui du compte s'il y en a un, sinon le profil local.
  String get _displayName =>
      _loggedIn ? (ApiService.user?.fullName ?? '') : _name;

  /// Sous-titre : spécialités et zones pour un pro, sinon métier / ville locaux.
  String get _subtitle {
    final pro = _account?['professional'] as Map?;
    if (_loggedIn && pro != null) {
      final specs = List<String>.from(pro['specialties'] ?? []);
      final zones = List<String>.from(pro['serviceZone'] ?? []);
      return [specs.join(', '), zones.join(', ')]
          .where((s) => s.isNotEmpty)
          .join(' • ');
    }
    if (_loggedIn) return 'Client Taara';
    return [_job, _city].where((s) => s.isNotEmpty).join(' • ');
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw != null) {
      final map = jsonDecode(raw);
      _name = map['name'] ?? '';
      _job = map['job'] ?? '';
      _city = map['city'] ?? '';
    }
    _nameCtrl.text = _name;
    _jobCtrl.text = _job;
    _cityCtrl.text = _city;
    if (_loggedIn) {
      try {
        _account = await ApiService.me();
        _firstNameCtrl.text = _account?['firstName'] ?? '';
        _lastNameCtrl.text = _account?['lastName'] ?? '';
        _phoneCtrl.text = _account?['phone'] ?? '';
      } on ApiException {
        // Hors-ligne : on garde les infos de la session
        final u = ApiService.user;
        _firstNameCtrl.text = u?.firstName ?? '';
        _lastNameCtrl.text = u?.lastName ?? '';
      }
    } else {
      _account = null;
    }
    final s = await HistoryService.stats();
    if (mounted)
      setState(() {
        _stats = s;
        _loading = false;
      });
  }

  Future<void> _saveProfile() async {
    if (_loggedIn) return _saveAccount();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profileKey,
      jsonEncode({
        'name': _nameCtrl.text.trim(),
        'job': _jobCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
      }),
    );
    setState(() {
      _name = _nameCtrl.text.trim();
      _job = _jobCtrl.text.trim();
      _city = _cityCtrl.text.trim();
      _editing = false;
    });
    if (mounted) showTaaraSnackbar(context, 'Profil sauvegardé ✓');
  }

  Future<void> _saveAccount() async {
    if (_firstNameCtrl.text.trim().isEmpty ||
        _lastNameCtrl.text.trim().isEmpty) {
      showTaaraSnackbar(context, 'Prénom et nom sont obligatoires',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.updateMe(
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        phone: _phoneCtrl.text,
      );
      if (!mounted) return;
      setState(() => _editing = false);
      showTaaraSnackbar(context, 'Profil enregistré ✓');
    } on ApiException catch (e) {
      if (mounted) showTaaraSnackbar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _initials {
    final name = _displayName.trim();
    final parts = name.split(RegExp(r'\s+'));
    if (name.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Profil',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () {
                    if (_editing) {
                      _saveProfile();
                    } else {
                      setState(() => _editing = true);
                    }
                  },
            child: Text(
              _saving ? '…' : (_editing ? 'ENREGISTRER' : 'MODIFIER'),
              style: TextStyle(
                color: _editing ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildAvatar(),
                  const SizedBox(height: 28),
                  _buildAccountCard(),
                  const SizedBox(height: 24),
                  _buildProfileCard(),
                  const SizedBox(height: 24),
                  _buildStatsSection(),
                  const SizedBox(height: 24),
                  _buildAboutSection(),
                  if (_loggedIn) ...[
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: _confirmDeleteAccount,
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppTheme.accent),
                      label: const Text('Supprimer mon compte',
                          style:
                              TextStyle(color: AppTheme.accent, fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            shape: BoxShape.circle,
            boxShadow: AppTheme.goldGlow,
          ),
          child: Center(
            child: Text(
              _initials,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppTheme.background,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _displayName.isEmpty ? 'Bienvenue sur Taara' : _displayName,
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        if (_subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ],
    );
  }

  // ── Compte TAARA (marketplace des réparateurs) ─────────────────────────────
  Widget _buildAccountCard() {
    return ValueListenableBuilder<TaaraUser?>(
      valueListenable: ApiService.currentUser,
      builder: (context, user, _) {
        return TaaraCard(
          withGoldBorder: user == null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text('Compte TAARA',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white)),
                  const Spacer(),
                  if (user != null)
                    Text(user.isPro ? 'PRO' : 'CLIENT',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                user == null
                    ? 'Connectez-vous pour contacter un réparateur vérifié et suivre vos demandes.'
                    : '${user.fullName}\n${user.email}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              if (user == null)
                GoldButton(
                  label: 'SE CONNECTER',
                  icon: Icons.login_rounded,
                  height: 48,
                  onTap: () => Navigator.pushNamed(context, '/auth'),
                )
              else
                Row(
                  children: [
                    if (user.isPro) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/pro-profile'),
                          icon: const Icon(Icons.badge_outlined,
                              size: 18, color: AppTheme.primary),
                          label: const Text('MA FICHE',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/my-jobs'),
                        icon: const Icon(Icons.assignment_outlined,
                            size: 18, color: AppTheme.primary),
                        label: Text(user.isPro ? 'MES JOBS' : 'MES DEMANDES',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Déconnexion',
                      onPressed: () async {
                        await ApiService.logout();
                        if (mounted) showTaaraSnackbar(context, 'Déconnecté');
                      },
                      icon: const Icon(Icons.logout_rounded,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Supprimer mon compte',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Votre profil, vos demandes, messages et notifications seront '
              'définitivement effacés. Cette action est irréversible.',
              style:
                  TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
    final password = ctrl.text;
    ctrl.dispose();
    if (ok != true || password.isEmpty) return;
    try {
      await ApiService.deleteAccount(password);
      if (mounted) showTaaraSnackbar(context, 'Compte supprimé');
    } on ApiException catch (e) {
      if (mounted) showTaaraSnackbar(context, e.message, isError: true);
    }
  }

  Widget _buildProfileCard() {
    return TaaraCard(
      withGoldBorder: _editing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Informations',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white)),
              const Spacer(),
              if (_editing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ÉDITION',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loggedIn) ..._accountFields() else ..._localFields(),
        ],
      ),
    );
  }

  List<Widget> _accountFields() {
    final pro = _account?['professional'] as Map?;
    return [
      _buildField(
        controller: _firstNameCtrl,
        label: 'Prénom',
        icon: Icons.badge_outlined,
        hint: 'Ex : Kofi',
      ),
      const SizedBox(height: 12),
      _buildField(
        controller: _lastNameCtrl,
        label: 'Nom',
        icon: Icons.badge_outlined,
        hint: 'Ex : Mensah',
      ),
      const SizedBox(height: 12),
      _buildField(
        controller: _phoneCtrl,
        label: 'Téléphone',
        icon: Icons.phone_outlined,
        hint: '+228 90 00 00 00',
      ),
      const SizedBox(height: 12),
      _buildReadOnly(
          'Email', Icons.alternate_email, ApiService.user?.email ?? '—'),
      if (pro != null) ...[
        const SizedBox(height: 14),
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/pro-profile')
              .then((_) => _loadData()),
          child: const Row(
            children: [
              Icon(Icons.handyman_outlined, color: AppTheme.primary, size: 16),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                    'Spécialités, zones et tarif : modifier ma fiche réparateur',
                    style: TextStyle(color: AppTheme.primary, fontSize: 13)),
              ),
              Icon(Icons.chevron_right, color: AppTheme.primary, size: 18),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _localFields() {
    return [
      _buildField(
        controller: _nameCtrl,
        label: 'Nom complet',
        icon: Icons.badge_outlined,
        hint: 'Ex: Kofi Mensah',
      ),
      const SizedBox(height: 12),
      _buildField(
        controller: _jobCtrl,
        label: 'Métier / Spécialité',
        icon: Icons.work_outline,
        hint: 'Ex: Mécanicien, Électricien...',
      ),
      const SizedBox(height: 12),
      _buildField(
        controller: _cityCtrl,
        label: 'Ville',
        icon: Icons.location_on_outlined,
        hint: 'Ex: Lomé, Dakar, Abidjan...',
      ),
    ];
  }

  Widget _buildReadOnly(String label, IconData icon, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(icon, color: AppTheme.primary, size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14, color: Colors.white70))),
        ]),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5)),
        const SizedBox(height: 6),
        _editing
            ? TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: Icon(icon, color: AppTheme.primary, size: 18),
                  hintText: hint,
                  hintStyle: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.surfaceHigh.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              )
            : Row(
                children: [
                  Icon(icon, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      controller.text.isEmpty ? '—' : controller.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: controller.text.isEmpty
                            ? AppTheme.textSecondary
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildStatsSection() {
    final total = _stats['total'] ?? 0;
    final critique = _stats['critique'] ?? 0;
    final attention = _stats['attention'] ?? 0;
    final bonEtat = _stats['bonEtat'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mes diagnostics',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        const SizedBox(height: 2),
        const Text('Enregistrés sur ce téléphone',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildStatBox(
                '$total', 'TOTAL', AppTheme.primary, Icons.analytics_outlined),
            const SizedBox(width: 10),
            _buildStatBox('$bonEtat', 'RÉSOLUS', Colors.greenAccent,
                Icons.check_circle_outline),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatBox('$critique', 'CRITIQUES', AppTheme.accent,
                Icons.warning_amber_rounded),
            const SizedBox(width: 10),
            _buildStatBox('$attention', 'ATTENTION', AppTheme.primary,
                Icons.info_outline),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBox(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return TaaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text('À propos de Taara',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          _buildAboutRow(Icons.wb_sunny_rounded, 'Version', '1.0.0'),
          const SizedBox(height: 10),
          _buildAboutRow(
              Icons.psychology_outlined, 'Diagnostic', 'IA Gemma 4 (Google)'),
          const SizedBox(height: 10),
          _buildAboutRow(Icons.place_outlined, 'Conçu à', 'Lomé, Togo'),
          if (Env.siteUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => launchUrl(
                  Uri.parse('${Env.siteUrl}/#confidentialite'),
                  mode: LaunchMode.externalApplication),
              child: _buildAboutRow(
                  Icons.privacy_tip_outlined, 'Confidentialité', 'Lire ›'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary.withOpacity(0.6), size: 16),
        const SizedBox(width: 12),
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(width: 12),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
