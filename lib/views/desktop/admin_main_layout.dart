import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../core/app_colors.dart';
import '../../shared/widgets/language_toggle_button.dart';
import '../admin/dashboard_screen.dart';
import 'pos_screen.dart';
import '../admin/ajouter_produit.dart';
import '../admin/liste_produits.dart';
import '../admin/gestion_employes.dart';
import '../admin/gestion_clients.dart';
import '../admin/gestion_fournisseurs.dart';
import '../admin/achat_fournisseur.dart';
import '../admin/purchase_orders_screen.dart';
import '../admin/activity_logs_screen.dart';
import '../admin/gestion_stores.dart';
import '../admin/inventory_screen.dart';
import '../admin/sales_history_screen.dart';
import '../admin/expenses_screen.dart';
import '../admin/debt_recovery_screen.dart';
import '../admin/health_screen.dart';
import '../admin/size_run_screen.dart';
import '../../widgets/offline_banner.dart';
import '../../services/notification_service.dart';
import '../admin/notifications_screen.dart';

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
      const PosScreen(),
      const GestionStoresScreen(),
      const InventoryScreen(),
      const SizeRunScreen(),
      ListeProduitsScreen(
        onAddProduct: () => setState(() => _selectedIndex = 6),
      ),
      const AjouterProduitScreen(),
      const GestionClientsScreen(),
      const GestionFournisseursScreen(),
      const AchatFournisseurScreen(),
      const PurchaseOrdersScreen(),
      const GestionEmployesScreen(),
      const ActivityLogsScreen(),
      const SalesHistoryScreen(),
      const ExpensesScreen(),
      const DebtRecoveryScreen(),
      const HealthScreen(),
    ];
  }

  static List<(IconData, IconData, String)> get _destinations => [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, S.t('nav_dashboard')),
    (Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, S.t('nav_pos')),
    (Icons.warehouse_outlined, Icons.warehouse_rounded, S.t('nav_stores')),
    (Icons.inventory_outlined, Icons.inventory_rounded, S.t('nav_inventory')),
    (Icons.straighten_outlined, Icons.straighten_rounded, S.t('nav_size_runs')),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded, S.t('nav_products')),
    (Icons.add_box_outlined, Icons.add_box_rounded, S.t('nav_add_product')),
    (Icons.people_outline, Icons.people_rounded, S.t('nav_clients')),
    (Icons.local_shipping_outlined, Icons.local_shipping_rounded, S.t('nav_suppliers')),
    (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, S.t('nav_purchases')),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Bons de commande'),
    (Icons.badge_outlined, Icons.badge_rounded, S.t('nav_employees')),
    (Icons.history_outlined, Icons.history_rounded, S.t('nav_activity')),
    (Icons.history_edu_outlined, Icons.history_edu_rounded, S.t('nav_sales')),
    (Icons.receipt_long_outlined, Icons.receipt_long, S.t('nav_expenses')),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, S.t('nav_recovery')),
    (Icons.monitor_heart_outlined, Icons.monitor_heart_rounded, 'Santé'),
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
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          Container(
            width: 260,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.sidebarTop, AppColors.sidebarBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: BorderDirectional(
                end: BorderSide(
                  color: AppColors.goldLight,
                  width: 0.16,
                ),
              ),
            ),
            child: Column(
              children: [
                Container(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 28, 20, 24),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.25),
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
                          color: AppColors.gold.withValues(alpha: 0.12),
                          border: Border.all(color: AppColors.gold, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.gold,
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
                          color: AppColors.gold.withValues(alpha: 0.7),
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
                              color: AppColors.gold.withValues(alpha: 0.2),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.auto_awesome,
                              color: AppColors.gold.withValues(alpha: 0.5),
                              size: 12,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 0.5,
                              color: AppColors.gold.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppColors.gold, AppColors.goldLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: GoogleFonts.playfairDisplay(
                                    color: AppColors.background,
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
                                          color: AppColors.gold,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        S.t('label_role_admin'),
                                        style: GoogleFonts.raleway(
                                          color: AppColors.gold,
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
                        color: AppColors.gold.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: NotificationService.instance.unreadCount,
                        builder: (context, count, _) {
                          return Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined,
                                    color: Colors.white70),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const NotificationsScreen()),
                                  );
                                },
                              ),
                              if (count > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const LanguageToggleButton(),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              Supabase.instance.client.auth.signOut(),
                          icon: const Icon(Icons.logout_rounded,
                              size: 16, color: Colors.redAccent),
                          label: Text(
                            S.t('auth_logout'),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const OfflineBanner(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _screens[_selectedIndex],
                  ),
                ),
              ],
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
              ? AppColors.gold.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.35)
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
                    ? AppColors.gold.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? AppColors.gold : Colors.white38,
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
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
