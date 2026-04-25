import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/services/history_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _profileKey = 'taara_profile';

  String _name = '';
  String _job = '';
  String _city = '';
  bool _editing = false;
  bool _loading = true;
  Map<String, int> _stats = {};

  late TextEditingController _nameCtrl;
  late TextEditingController _jobCtrl;
  late TextEditingController _cityCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _jobCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _jobCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
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
    final s = await HistoryService.stats();
    if (mounted) setState(() { _stats = s; _loading = false; });
  }

  Future<void> _saveProfile() async {
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

  String get _initials {
    final parts = _name.trim().split(' ');
    if (parts.isEmpty || _name.isEmpty) return '?';
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
                fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              if (_editing) {
                _saveProfile();
              } else {
                setState(() => _editing = true);
              }
            },
            child: Text(
              _editing ? 'SAUVEGARDER' : 'MODIFIER',
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
                  _buildProfileCard(),
                  const SizedBox(height: 24),
                  _buildStatsSection(),
                  const SizedBox(height: 24),
                  _buildAboutSection(),
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
          _name.isEmpty ? 'Technicien Taara' : _name,
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        if (_job.isNotEmpty || _city.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            [_job, _city].where((s) => s.isNotEmpty).join(' • '),
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ],
    );
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
        ],
      ),
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
                  prefixIcon:
                      Icon(icon, color: AppTheme.primary, size: 18),
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
                    borderSide: const BorderSide(
                        color: AppTheme.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                ),
              )
            : Row(
                children: [
                  Icon(icon, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 10),
                  Text(
                    controller.text.isEmpty ? '—' : controller.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: controller.text.isEmpty
                          ? AppTheme.textSecondary
                          : Colors.white,
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
        Text('Statistiques',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildStatBox('$total', 'TOTAL', AppTheme.primary,
                Icons.analytics_outlined),
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

  Widget _buildStatBox(
      String value, String label, Color color, IconData icon) {
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
          _buildAboutRow(Icons.psychology_outlined, 'Modèle IA', 'Gemma 4 — 26B'),
          const SizedBox(height: 10),
          _buildAboutRow(
              Icons.language, 'Hackathon', 'Gemma4 Developer Challenge'),
          const SizedBox(height: 10),
          _buildAboutRow(Icons.public, 'Impact', 'Afrique de l\'Ouest'),
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
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
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