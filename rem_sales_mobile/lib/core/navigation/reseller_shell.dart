import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/pages/auth_bloc.dart';
import '../../features/auth/presentation/pages/auth_event.dart';
import '../../features/sales/presentation/pages/sales_screen_page.dart';

/// Coquille de navigation revendeur : 6 onglets (les 5 de
/// ResellerDashboard.vue côté web + une carte logistique), avec un
/// `IndexedStack` pour préserver l'état de chaque onglet en arrière-plan
/// (pas de rechargement en changeant d'onglet, comme le tab-switch du web).
///
/// Remplace `SalesScreen` comme écran affiché une fois connecté — la caisse
/// existante devient le 2ème onglet, inchangée. Les 4 autres onglets sont
/// des espaces réservés le temps des phases suivantes (Position, Vue
/// d'ensemble, Historique, Stock & Commande, Carte).
class ResellerShell extends StatefulWidget {
  const ResellerShell({super.key});

  @override
  State<ResellerShell> createState() => _ResellerShellState();
}

class _ResellerShellState extends State<ResellerShell> {
  int _currentIndex = 0;

  static const _tabs = [
    _ShellTab(icon: Icons.dashboard_outlined, label: 'Vue d\'ensemble'),
    _ShellTab(icon: Icons.point_of_sale_outlined, label: 'Caisse'),
    _ShellTab(icon: Icons.inventory_2_outlined, label: 'Stock'),
    _ShellTab(icon: Icons.history_outlined, label: 'Historique'),
    _ShellTab(icon: Icons.my_location_outlined, label: 'Position'),
    _ShellTab(icon: Icons.map_outlined, label: 'Carte'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ROBUST ENTERPRISE MANAGEMENT',
          style: TextStyle(fontSize: 12, letterSpacing: 1.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () => context.read<AuthBloc>().add(LogoutRequestedEvent()),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _PlaceholderTab(label: 'Vue d\'ensemble'),
          SalesScreen(),
          _PlaceholderTab(label: 'Stock & Commande'),
          _PlaceholderTab(label: 'Historique'),
          _PlaceholderTab(label: 'Position'),
          _PlaceholderTab(label: 'Carte'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          for (final tab in _tabs)
            BottomNavigationBarItem(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Espace réservé pour un onglet pas encore implémenté (phases suivantes).
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$label — bientôt disponible',
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}
