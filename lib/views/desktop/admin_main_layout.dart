import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../desktop/pos_screen.dart';
import '../admin/ajouter_produit.dart';
import '../admin/gestion_employes.dart';
import '../admin/gestion_clients.dart';
import '../admin/activity_logs_screen.dart';

class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({super.key});

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const PosScreen(),
    const AjouterProduitScreen(),
    const GestionClientsScreen(),
    const GestionEmployesScreen(),
    const ActivityLogsScreen(),
  ];

  final List<String> _titles = [
    'Point de Vente (POS)',
    'Gestion des Produits',
    'Gestion des Clients',
    'Gestion des Employés',
    'Journaux d\'activité',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            backgroundColor: Colors.indigo[900],
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            extended: true,
            minExtendedWidth: 250,
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            leading: Column(
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.storefront, size: 64, color: Colors.white),
                const SizedBox(height: 8),
                const Text("GestionStock", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
              ],
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    tooltip: 'Se déconnecter',
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale),
                label: Text('Point de Vente'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Produits'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Clients'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.badge_outlined),
                selectedIcon: Icon(Icons.badge),
                label: Text('Employés'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('Journaux d\'activité'),
              ),
            ],
          ),
          
          // Main Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _screens[_selectedIndex],
            ),
          )
        ],
      ),
    );
  }
}
