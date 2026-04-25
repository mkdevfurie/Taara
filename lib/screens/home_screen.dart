import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';
import 'package:taara/models/diagnostic_model.dart';
import 'package:taara/services/history_service.dart';
import 'package:taara/screens/history_screen.dart';
import 'package:taara/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // 0=Accueil 1=Historique 2=Profil

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _DashboardPage(onRefresh: _refresh),
      const HistoryScreen(),
      const ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args == 'repair_done' && mounted) {
        showTaaraSnackbar(context, '✅ Réparation terminée avec succès !');
      }
    });
  }

  void _refresh() => setState(() {});

  Future<void> _onNavTap(int i) async {
    // Index 1 = SCAN → ouvre la caméra
    if (i == 1) {
      final result = await Navigator.pushNamed(context, '/scan');
      if (result is DiagnosticModel && mounted) {
        await HistoryService.add(result);
        setState(() => _currentIndex = 1);
      }
      return;
    }
    final pageMap = {0: 0, 2: 1, 3: 2};
    final page = pageMap[i];
    if (page != null) setState(() => _currentIndex = page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final navIndex = _currentIndex == 0 ? 0 : _currentIndex == 1 ? 2 : 3;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1320),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: navIndex,
        onTap: _onNavTap,
        backgroundColor: Colors.transparent,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedFontSize: 9,
        unselectedFontSize: 9,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'ACCUEIL'),
          BottomNavigationBarItem(
              icon: Icon(Icons.center_focus_strong_rounded), label: 'SCAN'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded), label: 'HISTORIQUE'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'PROFIL'),
        ],
      ),
    );
  }
}

// ─── Dashboard ───────────────────────────────────────────────────────────────
class _DashboardPage extends StatefulWidget {
  final VoidCallback onRefresh;
  const _DashboardPage({required this.onRefresh});

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  List<DiagnosticModel> _recent = [];
  Map<String, int> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final history = await HistoryService.load();
    final stats = await HistoryService.stats();
    if (mounted) {
      setState(() {
        _recent = history.take(3).toList();
        _stats = stats;
        _loading = false;
      });
    }
  }

  Future<void> _launchScan() async {
    final result = await Navigator.pushNamed(context, '/scan');
    if (result is DiagnosticModel && mounted) {
      await HistoryService.add(result);
      await _loadData();
      widget.onRefresh();
    }
  }

  Future<void> _launchVoice() async {
    await Navigator.pushNamed(context, '/voice');
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 8)
                ],
              ),
              child: const Icon(Icons.wb_sunny_rounded,
                  color: AppTheme.background, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Taara',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    letterSpacing: 2)),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: OfflineBadge()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Bouton SCAN principal
              _buildScanButton(),
              const SizedBox(height: 12),
              // Bouton VOCAL secondaire (plus petit)
              _buildVoiceButton(),
              const SizedBox(height: 28),
              _loading ? _buildStatsShimmer() : _buildStats(),
              const SizedBox(height: 28),
              Text('Diagnostics récents',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 16),
              _loading
                  ? const Center(
                      child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                              color: AppTheme.primary)))
                  : _recent.isEmpty
                      ? _buildEmptyState()
                      : _buildRecentList(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: _launchScan,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.goldGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.goldGlow,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20, top: -20,
              child: Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded,
                      size: 46, color: AppTheme.background),
                  SizedBox(height: 10),
                  Text('Diagnostiquer',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.background)),
                  SizedBox(height: 4),
                  Text("Filmez l'objet à réparer",
                      style: TextStyle(
                          color: AppTheme.background, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onTap: _launchVoice,
      child: Container(
        height: 64,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded,
                  color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Décrire vocalement',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                Text('Expliquez le problème avec votre voix',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary)),
              ],
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.arrow_forward_ios,
                  color: AppTheme.textSecondary, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        _buildStatCard('${_stats['total'] ?? 0}', 'DIAGNOSTICS',
            Icons.analytics_outlined),
        const SizedBox(width: 12),
        _buildStatCard(
            '${_stats['bonEtat'] ?? 0}', 'RÉSOLUS', Icons.check_circle_outline),
        const SizedBox(width: 12),
        _buildStatCard('IA', 'GEMMA 4', Icons.psychology_outlined),
      ],
    );
  }

  Widget _buildStatsShimmer() {
    return Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                  color: AppTheme.surfaceLow,
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Expanded(
      child: TaaraCard(
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return TaaraCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.search_outlined,
                color: AppTheme.primary.withOpacity(0.3), size: 56),
            const SizedBox(height: 16),
            const Text('Aucun diagnostic encore',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Utilisez la caméra ou le mode vocal\npour analyser un objet avec Gemma 4',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentList() {
    return Column(
      children: _recent.map((d) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TaaraCard(
            onTap: () =>
                Navigator.pushNamed(context, '/result', arguments: d),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.build_outlined,
                      color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.objectName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('${(d.confidence * 100).toInt()}% confiance',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                StatusBadge(status: d.status),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}