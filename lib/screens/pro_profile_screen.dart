import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/services/api_service.dart';
import 'package:taara/services/realtime_service.dart';

/// Fiche du réparateur : ce que les clients voient, et ce que l'équipe Taara
/// contrôle avant de le vérifier (spécialités, zone, tarif, justificatifs).
class ProProfileScreen extends StatefulWidget {
  const ProProfileScreen({super.key});

  @override
  State<ProProfileScreen> createState() => _ProProfileScreenState();
}

class _ProProfileScreenState extends State<ProProfileScreen> {
  static const _allSpecialties = [
    'Électricien',
    'Mécanicien',
    'Plombier',
    'Électronicien',
    'Frigoriste',
    'Soudeur',
    'Réparateur de machines à coudre',
  ];

  final _zoneCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final Set<String> _specialties = {};
  List<String> _certifications = [];
  String? _proId;
  bool _verified = false;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  StreamSubscription<Map<String, dynamic>>? _notifSub;

  @override
  void initState() {
    super.initState();
    _load();
    // L'équipe vient de vérifier (ou de retirer) le profil : on se met à jour aussitôt
    _notifSub = RealtimeService.notifications
        .where((n) =>
            n['data'] is Map && (n['data'] as Map)['professionalId'] != null)
        .listen((_) => _load(silent: true));
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _zoneCtrl.dispose();
    _rateCtrl.dispose();
    _expCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final me = await ApiService.me();
      final pro = me['professional'] as Map?;
      if (!mounted) return;
      if (pro == null) {
        showTaaraSnackbar(context, 'Ce compte n\'a pas de fiche réparateur',
            isError: true);
        Navigator.pop(context);
        return;
      }
      setState(() {
        _proId = pro['id'] as String;
        _verified = pro['isVerified'] == true;
        _specialties
          ..clear()
          ..addAll(List<String>.from(pro['specialties'] ?? []));
        _certifications = List<String>.from(pro['certifications'] ?? []);
        if (!silent) {
          _zoneCtrl.text =
              List<String>.from(pro['serviceZone'] ?? []).join(', ');
          final rate = (pro['hourlyRate'] ?? 0).toDouble();
          _rateCtrl.text = rate > 0 ? rate.toStringAsFixed(0) : '';
          final exp = (pro['experience'] ?? 0) as num;
          _expCtrl.text = exp > 0 ? '$exp' : '';
          _bioCtrl.text = pro['bio'] ?? '';
        }
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showTaaraSnackbar(context, e.message, isError: true);
    }
  }

  List<String> get _missing => [
        if (_specialties.isEmpty) 'au moins une spécialité',
        if (_zoneCtrl.text.trim().isEmpty) 'votre ville ou quartier',
        if ((double.tryParse(_rateCtrl.text) ?? 0) <= 0) 'votre tarif horaire',
        if (_bioCtrl.text.trim().length < 20)
          'une présentation (20 caractères min.)',
        if (_certifications.isEmpty) 'au moins un justificatif',
      ];

  Future<void> _save() async {
    if (_proId == null) return;
    if (_specialties.isEmpty) {
      showTaaraSnackbar(context, 'Choisissez au moins une spécialité',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.updateProfessional(_proId!, {
        'specialties': _specialties.toList(),
        'serviceZone': _zoneCtrl.text
            .split(',')
            .map((z) => z.trim())
            .where((z) => z.isNotEmpty)
            .toList(),
        'hourlyRate': double.tryParse(_rateCtrl.text.replaceAll(' ', '')) ?? 0,
        'experience': int.tryParse(_expCtrl.text) ?? 0,
        'bio': _bioCtrl.text.trim(),
      });
      if (mounted) showTaaraSnackbar(context, 'Fiche enregistrée ✓');
    } on ApiException catch (e) {
      if (mounted) showTaaraSnackbar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addDocument(ImageSource source) async {
    if (_proId == null) return;
    final file = await ImagePicker()
        .pickImage(source: source, imageQuality: 80, maxWidth: 2000);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      await ApiService.uploadCertification(
          _proId!, await file.readAsBytes(), file.name);
      await _load(silent: true);
      if (mounted) showTaaraSnackbar(context, 'Justificatif envoyé ✓');
    } on ApiException catch (e) {
      if (mounted) showTaaraSnackbar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeDocument(String url) async {
    try {
      await ApiService.removeCertification(_proId!, url);
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) showTaaraSnackbar(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
          title: Text('Ma fiche réparateur',
              style: GoogleFonts.poppins(fontSize: 17))),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _statusCard(),
                const SizedBox(height: 22),
                _label('Spécialités'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in {..._allSpecialties, ..._specialties})
                      FilterChip(
                        label: Text(s),
                        selected: _specialties.contains(s),
                        onSelected: (on) => setState(() =>
                            on ? _specialties.add(s) : _specialties.remove(s)),
                        selectedColor: AppTheme.primary,
                        backgroundColor: AppTheme.surface,
                        checkmarkColor: AppTheme.background,
                        labelStyle: TextStyle(
                          color: _specialties.contains(s)
                              ? AppTheme.background
                              : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide.none,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _field(_zoneCtrl, 'Zones d\'intervention',
                    'Lomé, Bè, Adidogomé', Icons.place_outlined),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _field(_rateCtrl, 'Tarif horaire (FCFA)', '3000',
                        Icons.payments_outlined,
                        keyboard: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_expCtrl, 'Années d\'expérience', '5',
                        Icons.workspace_premium_outlined,
                        keyboard: TextInputType.number),
                  ),
                ]),
                const SizedBox(height: 12),
                _field(
                    _bioCtrl,
                    'Présentation',
                    'Ce que vous réparez, votre atelier, vos horaires…',
                    Icons.notes_rounded,
                    maxLines: 4),
                const SizedBox(height: 16),
                _saving
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.primary))
                    : GoldButton(
                        label: 'ENREGISTRER MA FICHE',
                        icon: Icons.save_outlined,
                        onTap: _save),
                const SizedBox(height: 28),
                _label('Justificatifs'),
                const Text(
                  'Diplôme, attestation d\'un employeur, carte professionnelle ou photo de votre atelier. '
                  'Seule l\'équipe Taara les voit, pour vérifier votre profil.',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                if (_certifications.isNotEmpty)
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _certifications.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => _docThumb(_certifications[i]),
                    ),
                  ),
                const SizedBox(height: 12),
                _uploading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.primary))
                    : Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _addDocument(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined,
                                color: AppTheme.primary, size: 18),
                            label: const Text('PHOTO',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _addDocument(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined,
                                color: AppTheme.primary, size: 18),
                            label: const Text('GALERIE',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ]),
              ],
            ),
    );
  }

  Widget _statusCard() {
    final missing = _missing;
    final color = _verified ? Colors.greenAccent : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
                _verified
                    ? Icons.verified_rounded
                    : Icons.hourglass_top_rounded,
                color: color,
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _verified
                    ? 'Profil vérifié — visible par les clients'
                    : 'En attente de vérification',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            _verified
                ? 'Gardez votre fiche à jour : c\'est ce que les clients voient avant de vous contacter.'
                : missing.isEmpty
                    ? 'Votre fiche est complète. L\'équipe Taara la vérifie, vous serez prévenu ici.'
                    : 'Pour être vérifié, ajoutez : ${missing.join(', ')}.',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _docThumb(String url) {
    final isPdf = url.toLowerCase().endsWith('.pdf');
    return Stack(
      children: [
        GestureDetector(
          onTap: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 96,
              height: 96,
              color: AppTheme.surface,
              child: isPdf
                  ? const Icon(Icons.picture_as_pdf_outlined,
                      color: AppTheme.primary, size: 36)
                  : Image.network(url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.description_outlined,
                          color: AppTheme.textSecondary)),
            ),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: GestureDetector(
            onTap: () => _removeDocument(url),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  color: Colors.black87, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      );

  Widget _field(
      TextEditingController c, String label, String hint, IconData icon,
      {TextInputType? keyboard, int maxLines = 1}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        labelStyle:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      ),
    );
  }
}
