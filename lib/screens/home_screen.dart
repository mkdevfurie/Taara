import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/widgets/global_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Bonjour, Technicien 👋',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(child: OfflineBadge()),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildHeroButton(context),
            const SizedBox(height: 28),
            _buildStats(),
            const SizedBox(height: 28),
            _buildSectionHeader(context, 'Diagnostics récents'),
            const SizedBox(height: 16),
            _buildRecentList(),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeroButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/scan'),
      child: Container(
        height: 170,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.goldGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.goldGlow,
        ),
        child: Stack(
          children: [
            // Pattern décoratif en fond
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: -30,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // Contenu
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded,
                      size: 50, color: AppTheme.background),
                  SizedBox(height: 12),
                  Text(
                    'Diagnostiquer',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.background,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Filmez l'objet à réparer",
                    style: TextStyle(
                      color: AppTheme.background,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        _buildStatCard('0', 'DIAGNOSTICS', Icons.analytics_outlined),
        const SizedBox(width: 12),
        _buildStatCard('0', 'RÉSOLUS', Icons.check_circle_outline),
        const SizedBox(width: 12),
        _buildStatCard('OFF', 'MODE', Icons.wifi_off_rounded),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Expanded(
      child: TaaraCard(
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text(
            'VOIR TOUT',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentList() {
    return Column(
      children: [
        _buildListItem(
          'Alternateur Bosch AL65J',
          'CRITIQUE',
          'Il y a 2h • Secteur mécanique',
          Icons.electric_bolt,
        ),
        const SizedBox(height: 12),
        _buildListItem(
          'Pompe Hydraulique X-200',
          'RÉSOLU',
          'Hier • Secteur hydraulique',
          Icons.water_drop_outlined,
        ),
        const SizedBox(height: 12),
        _buildListItem(
          'Carte Mère G-Link Pro',
          'ATTENTION',
          'Il y a 3 jours • Électronique',
          Icons.developer_board,
        ),
      ],
    );
  }

  Widget _buildListItem(
      String title, String status, String subtitle, IconData icon) {
    Color statusColor;
    switch (status) {
      case 'CRITIQUE':
        statusColor = AppTheme.accent;
        break;
      case 'RÉSOLU':
        statusColor = Colors.greenAccent;
        break;
      default:
        statusColor = AppTheme.primary;
    }

    return TaaraCard(
      child: Row(
        children: [
          // Icône objet
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Badge statut
          StatusBadge(status: status),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1320),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'ACCUEIL',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.center_focus_strong_rounded),
            label: 'SCAN',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'HISTORIQUE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'PROFIL',
          ),
        ],
      ),
    );
  }
}