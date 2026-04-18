import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../desktop/pos_screen.dart';
import '../admin/ajouter_produit.dart';
import '../admin/liste_produits.dart';
import '../admin/gestion_clients.dart';
import '../admin/gestion_fournisseurs.dart';
import '../admin/achat_fournisseur.dart';
import '../admin/sales_history_screen.dart';
import '../../core/app_session.dart';
import '../../services/shift_service.dart';
import 'end_of_day_report.dart';

class EmployeeMainLayout extends StatefulWidget {
  const EmployeeMainLayout({super.key});

  @override
  State<EmployeeMainLayout> createState() => _EmployeeMainLayoutState();
}

class _EmployeeMainLayoutState extends State<EmployeeMainLayout> {
 
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const PosScreen(),
      ListeProduitsScreen(
        onAddProduct: () => setState(() => _selectedIndex = 2),
      ),
      const AjouterProduitScreen(),
      const GestionClientsScreen(),
      const GestionFournisseursScreen(),
      const AchatFournisseurScreen(),
      const SalesHistoryScreen(),
    ];
  }

  
  static const _darkBg = Color(0xFF0F0F1A);
  static const _sidebarTop = Color(0xFF1A1A2E);
  static const _sidebarBottom = Color(0xFF16213E);
  static const _gold = Color(0xFFD4A843);
  static const _goldLight = Color(0xFFF0C96B);


  @override
  Widget build(BuildContext context) {
    final employeeName =
        Supabase.instance.client.auth.currentUser?.email?.split('@').first ??
            'Employé';
    final initials = employeeName.isNotEmpty
        ? employeeName[0].toUpperCase()
        : 'E';

    return Scaffold(
      backgroundColor: _darkBg,
      body: Row(
        children: [
         
          Container(
            width: 240,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_sidebarTop, _sidebarBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(
                right: BorderSide(
                  color: Color(0x33D4A843),
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
                        color: _gold.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                   
                      Stack(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [_gold, _goldLight],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _gold.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: GoogleFonts.playfairDisplay(
                                  color: _darkBg,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                         
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: _PulseDot(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        employeeName,
                        style: GoogleFonts.raleway(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _gold.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Text(
                          'Espace Employé',
                          style: GoogleFonts.raleway(
                            color: _gold,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 12),
                    child: Column(
                      children: [
                        _buildNavItem(0, Icons.point_of_sale_outlined,
                            Icons.point_of_sale_rounded, 'Point de Vente'),
                        _buildNavItem(1, Icons.inventory_2_outlined,
                            Icons.inventory_2_rounded, 'Produits'),
                        _buildNavItem(2, Icons.add_box_outlined,
                            Icons.add_box_rounded, 'Ajouter Produit'),
                        _buildNavItem(3, Icons.people_outline,
                            Icons.people_rounded, 'Clients'),
                        _buildNavItem(4, Icons.local_shipping_outlined,
                            Icons.local_shipping_rounded, 'Fournisseurs'),
                        _buildNavItem(5, Icons.shopping_bag_outlined,
                            Icons.shopping_bag_rounded, 'Achats'),
                        _buildNavItem(6, Icons.history_edu_outlined,
                            Icons.history_edu_rounded, 'Mes Ventes'),
                      ],
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
                  child: Column(
                    children: [
                     
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => EndOfDayReport(
                                date: DateTime.now(),
                                shiftId: AppSession.currentShiftId,
                              ),
                            ).then((val) {
                              if (val == true) setState(() {});
                            });
                          },
                          icon: const Icon(Icons.assessment_rounded, size: 18),
                          label: Text(
                            'تقرير اليوم',
                            style: GoogleFonts.raleway(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: _darkBg,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                     
                      SizedBox(
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
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(
                                color: Colors.redAccent.withValues(alpha: 0.4),
                                width: 0.8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
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
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? _gold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? _gold.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? _gold : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.raleway(
                color: isSelected ? _gold : Colors.white60,
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: _gold,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(
            const Color(0xFF4CAF50),
            const Color(0xFF81C784),
            _anim.value,
          ),
          border: Border.all(color: const Color(0xFF1A1A2E), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.5 * _anim.value),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}