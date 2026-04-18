import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin/dashboard_screen.dart';
import '../admin/ajouter_produit.dart';
import '../admin/liste_produits.dart';
import '../admin/gestion_employes.dart';
import '../admin/gestion_clients.dart';
import '../admin/gestion_fournisseurs.dart';
import '../admin/achat_fournisseur.dart';
import '../admin/activity_logs_screen.dart';
import '../admin/gestion_stores.dart';
import '../admin/inventory_screen.dart';
import '../admin/sales_history_screen.dart';

class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({super.key});

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {

  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DashboardScreen(),
      const GestionStoresScreen(),
      const InventoryScreen(),
      ListeProduitsScreen(
        onAddProduct: () => setState(() => _selectedIndex = 4),
      ),
      const AjouterProduitScreen(),
      const GestionClientsScreen(),
      const GestionFournisseursScreen(),
      const AchatFournisseurScreen(),
      const GestionEmployesScreen(),
      const ActivityLogsScreen(),
      const SalesHistoryScreen(),
    ];
  }

  
  static const _darkBg = Color(0xFF0F0F1A);
  static const _sidebarTop = Color(0xFF1A1A2E);
  static const _sidebarBottom = Color(0xFF0D0D1F);
  static const _gold = Color(0xFFD4A843);
  static const _goldLight = Color(0xFFF0C96B);


  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Tableau de Bord'),
    (Icons.warehouse_outlined, Icons.warehouse_rounded, 'Magasins'),
    (Icons.inventory_outlined, Icons.inventory_rounded, 'Inventaire'),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Produits'),
    (Icons.add_box_outlined, Icons.add_box_rounded, 'Ajouter Produit'),
    (Icons.people_outline, Icons.people_rounded, 'Clients'),
    (Icons.local_shipping_outlined, Icons.local_shipping_rounded, 'Fournisseurs'),
    (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'Achats'),
    (Icons.badge_outlined, Icons.badge_rounded, 'Employés'),
    (Icons.history_outlined, Icons.history_rounded, "Journaux d'activité"),
    (Icons.history_edu_outlined, Icons.history_edu_rounded, 'Historique Ventes'),
  ];

  @override
  Widget build(BuildContext context) {
    final adminEmail =
        Supabase.instance.client.auth.currentUser?.email?.split('@').first ??
            'Admin';
    final initials = adminEmail.isNotEmpty
        ? adminEmail[0].toUpperCase()
        : 'A';

    return Scaffold(
      backgroundColor: _darkBg,
      body: Row(
        children: [
       
          Container(
            width: 260,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_sidebarTop, _sidebarBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(
                right: BorderSide(
                  color: Color(0x44D4A843),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
       
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _gold.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
             
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _gold.withValues(alpha: 0.12),
                          border: Border.all(color: _gold, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: _gold,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'STEPZONE',
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ERP · Gestion',
                        style: GoogleFonts.raleway(
                          color: _gold.withValues(alpha: 0.7),
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                  
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 0.5,
                              color: _gold.withValues(alpha: 0.2),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.auto_awesome,
                              color: _gold.withValues(alpha: 0.5),
                              size: 12,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 0.5,
                              color: _gold.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                   
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            // أيقونة المدير
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [_gold, _goldLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: GoogleFonts.playfairDisplay(
                                    color: _darkBg,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    adminEmail,
                                    style: GoogleFonts.raleway(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: _gold,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Administrateur',
                                        style: GoogleFonts.raleway(
                                          color: _gold,
                                          fontSize: 10,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    child: ListView.builder(
                      itemCount: _destinations.length,
                      itemBuilder: (context, index) {
                        return _buildNavItem(
                          index,
                          _destinations[index].$1,
                          _destinations[index].$2,
                          _destinations[index].$3,
                        );
                      },
                    ),
                  ),
                ),

    
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: _gold.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Supabase.instance.client.auth.signOut(),
                      icon: const Icon(Icons.logout_rounded,
                          size: 16, color: Colors.redAccent),
                      label: Text(
                        'Déconnexion',
                        style: GoogleFonts.raleway(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

       
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildNavItem(
      int index, IconData icon, IconData selectedIcon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 2),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? _gold.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? _gold.withValues(alpha: 0.35)
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
          
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? _gold.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? _gold : Colors.white38,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.raleway(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
         
            if (isSelected)
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}