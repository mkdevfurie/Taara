import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/services/api_service.dart';

/// Connexion / inscription au compte TAARA.
/// Renvoie `true` via Navigator.pop quand l'utilisateur est connecté.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _isRegister = false;
  bool _asPro = false;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = _isRegister
          ? await ApiService.register(
              email: _emailCtrl.text,
              phone: _phoneCtrl.text,
              firstName: _firstNameCtrl.text,
              lastName: _lastNameCtrl.text,
              password: _passwordCtrl.text,
              asPro: _asPro,
            )
          : await ApiService.login(_emailCtrl.text, _passwordCtrl.text);
      if (!mounted) return;
      showTaaraSnackbar(context, 'Bienvenue ${user.firstName} ✓');
      if (_isRegister && user.isPro) {
        // Nouveau réparateur : on l'amène directement à sa fiche (nécessaire pour être vérifié)
        Navigator.pushReplacementNamed(context, '/pro-profile', result: true);
      } else {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) showTaaraSnackbar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      showTaaraSnackbar(context, 'Saisissez d\'abord votre email',
          isError: true);
      return;
    }
    try {
      await ApiService.forgotPassword(email);
      if (mounted) {
        showTaaraSnackbar(context,
            'Si ce compte existe, un email de réinitialisation a été envoyé');
      }
    } on ApiException catch (e) {
      if (mounted) showTaaraSnackbar(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isRegister ? 'Créer un compte' : 'Connexion',
            style: GoogleFonts.poppins(fontSize: 17)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Votre compte TAARA permet de contacter un réparateur vérifié '
                  'près de chez vous et de suivre vos demandes.',
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 24),
                if (_isRegister) ...[
                  const Text('Vous êtes :',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _roleCard(
                          selected: !_asPro,
                          icon: Icons.person_search_rounded,
                          title: 'Client',
                          subtitle: 'Je cherche à faire réparer',
                          onTap: () => setState(() => _asPro = false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _roleCard(
                          selected: _asPro,
                          icon: Icons.engineering_rounded,
                          title: 'Réparateur',
                          subtitle: 'Je propose mes services',
                          onTap: () => setState(() => _asPro = true),
                        ),
                      ),
                    ],
                  ),
                  if (_asPro) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '3 mois offerts, puis abonnement. Votre profil est vérifié par l\'équipe Taara '
                      '(avec ou sans diplôme) avant d\'apparaître aux clients.',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                          child: _field(
                              _firstNameCtrl, 'Prénom', Icons.person_outline)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _field(
                              _lastNameCtrl, 'Nom', Icons.badge_outlined)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _field(
                    _phoneCtrl,
                    'Téléphone (ex : +22890123456)',
                    Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                    validator: (v) => RegExp(r'^\+?[1-9]\d{6,14}$')
                            .hasMatch((v ?? '').replaceAll(' ', ''))
                        ? null
                        : 'Numéro invalide',
                  ),
                  const SizedBox(height: 14),
                ],
                _field(
                  _emailCtrl,
                  'Email',
                  Icons.alternate_email,
                  keyboard: TextInputType.emailAddress,
                  validator: (v) =>
                      (v ?? '').contains('@') ? null : 'Email invalide',
                ),
                const SizedBox(height: 14),
                _field(
                  _passwordCtrl,
                  'Mot de passe',
                  Icons.lock_outline,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppTheme.textSecondary,
                        size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'Mot de passe requis';
                    if (_isRegister && v!.length < 8)
                      return '8 caractères minimum';
                    return null;
                  },
                ),
                if (!_isRegister)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : _forgotPassword,
                      child: const Text('Mot de passe oublié ?',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ),
                  ),
                const SizedBox(height: 20),
                _loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.primary))
                    : GoldButton(
                        label:
                            _isRegister ? 'CRÉER MON COMPTE' : 'SE CONNECTER',
                        icon: _isRegister
                            ? Icons.person_add_alt_1
                            : Icons.login_rounded,
                        onTap: _submit,
                      ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _isRegister = !_isRegister),
                  child: Text(
                    _isRegister
                        ? 'Déjà inscrit ? Se connecter'
                        : 'Pas encore de compte ? S\'inscrire',
                    style: const TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withOpacity(0.12)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.white12,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon,
                  color: selected ? AppTheme.primary : AppTheme.textSecondary),
              const Spacer(),
              Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: selected ? AppTheme.primary : Colors.white24),
            ]),
            const SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator:
          validator ?? (v) => (v ?? '').trim().isEmpty ? 'Champ requis' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
      ),
    );
  }
}
