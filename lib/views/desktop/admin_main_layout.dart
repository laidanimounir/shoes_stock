import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
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

// ─── Admin Color Palette (Shoe Store – Dark Professional) ──────────────────
// Inspired by premium leather goods: deep navy, warm gold, crisp white.
// These are used locally here; migrate to AppColors if you want global access.
class _AdminPalette {
  // Sidebar background – deep navy (like premium shoe box packaging)
  static const sidebarBg = Color(0xFF0F1A2E);
  // Sidebar selected item
  static const sidebarSelected = Color(0xFF1E3A5F);
  // Gold accent – stitching / luxury touch
  static const gold = Color(0xFFD4A853);
  static const goldLight = Color(0x22D4A853);
  // Text
  static const textPrimary = Color(0xFFECEFF4);
  static const textMuted = Color(0xFF8A9BB5);
  // Section divider
  static const divider = Color(0xFF1E2D45);
  // Header
  static const headerBg = Color(0xFF0B1220);
  static const headerBorder = Color(0xFF1E2D45);
  // Stat chip background
  static const chipBg = Color(0xFF162035);
  // Online indicator
  static const online = Color(0xFF4CAF50);
  static const offline = Color(0xFFEF5350);
}

// ─── Nav item model ────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
  final int? badge; // optional badge count

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
    this.badge,
  });
}

// ─── Nav groups ────────────────────────────────────────────────────────────
class _NavGroup {
  final String titleKey; // translation key for group label
  final List<_NavItem> items;

  const _NavGroup({required this.titleKey, required this.items});
}

class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({super.key});

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  // ── Live clock ─────────────────────────────────────────────────────────
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  // ── Hardcoded header data – REPLACE WITH REAL SUPABASE QUERIES ─────────
  // TODO: fetch from your stores table using the logged-in user's store_id
  final String _currentStoreName = 'AIN DHAB';
  // TODO: replace with real connectivity check (e.g. ConnectivityService)
  final bool _isOnline = true;
  // TODO: fetch from sales table WHERE date = today AND store_id = current
  final double _todaySales = 145750.0;
  // TODO: fetch count of today's transactions
  final int _todayTransactions = 23;
  // TODO: fetch best selling product name today
  final String _bestProduct = 'Nike Air Max 270';
  // TODO: fetch low stock count (items below min threshold)
  final int _lowStockCount = 4;

  // ── Nav groups definition ───────────────────────────────────────────────
  static List<_NavGroup> get _groups => [
        _NavGroup(
          titleKey: 'nav_group_main',
          items: [
            _NavItem(
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard_rounded,
              labelKey: 'nav_dashboard',
            ),
            _NavItem(
              icon: Icons.point_of_sale_outlined,
              selectedIcon: Icons.point_of_sale_rounded,
              labelKey: 'nav_pos',
            ),
          ],
        ),
        _NavGroup(
          titleKey: 'nav_group_inventory',
          items: [
            _NavItem(
              icon: Icons.warehouse_outlined,
              selectedIcon: Icons.warehouse_rounded,
              labelKey: 'nav_stores',
            ),
            _NavItem(
              icon: Icons.inventory_outlined,
              selectedIcon: Icons.inventory_rounded,
              labelKey: 'nav_inventory',
            ),
            _NavItem(
              icon: Icons.straighten_outlined,
              selectedIcon: Icons.straighten_rounded,
              labelKey: 'nav_size_runs',
            ),
            _NavItem(
              icon: Icons.inventory_2_outlined,
              selectedIcon: Icons.inventory_2_rounded,
              labelKey: 'nav_products',
            ),
            _NavItem(
              icon: Icons.add_box_outlined,
              selectedIcon: Icons.add_box_rounded,
              labelKey: 'nav_add_product',
            ),
          ],
        ),
        _NavGroup(
          titleKey: 'nav_group_people',
          items: [
            _NavItem(
              icon: Icons.people_outline,
              selectedIcon: Icons.people_rounded,
              labelKey: 'nav_clients',
            ),
            _NavItem(
              icon: Icons.local_shipping_outlined,
              selectedIcon: Icons.local_shipping_rounded,
              labelKey: 'nav_suppliers',
            ),
            _NavItem(
              icon: Icons.badge_outlined,
              selectedIcon: Icons.badge_rounded,
              labelKey: 'nav_employees',
            ),
          ],
        ),
        _NavGroup(
          titleKey: 'nav_group_purchases',
          items: [
            _NavItem(
              icon: Icons.shopping_bag_outlined,
              selectedIcon: Icons.shopping_bag_rounded,
              labelKey: 'nav_purchases',
            ),
            _NavItem(
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long_rounded,
              labelKey: 'nav_purchase_orders',
            ),
          ],
        ),
        _NavGroup(
          titleKey: 'nav_group_reports',
          items: [
            _NavItem(
              icon: Icons.history_edu_outlined,
              selectedIcon: Icons.history_edu_rounded,
              labelKey: 'nav_sales',
            ),
            _NavItem(
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long,
              labelKey: 'nav_expenses',
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_outlined,
              selectedIcon: Icons.account_balance_wallet,
              labelKey: 'nav_recovery',
            ),
            _NavItem(
              icon: Icons.history_outlined,
              selectedIcon: Icons.history_rounded,
              labelKey: 'nav_activity',
            ),
            _NavItem(
              icon: Icons.monitor_heart_outlined,
              selectedIcon: Icons.monitor_heart_rounded,
              labelKey: 'nav_health',
            ),
          ],
        ),
      ];

  // Flat list to map _selectedIndex → screen
  static List<_NavItem> get _flatItems =>
      _groups.expand((g) => g.items).toList();

  @override
  void initState() {
    super.initState();

    _screens = [
      // ── MAIN ─────────────────────────────────────────────────────────
      const DashboardScreen(),    // 0 – dashboard
      const PosScreen(),          // 1 – POS
      // ── INVENTORY ────────────────────────────────────────────────────
      const GestionStoresScreen(),// 2 – stores
      const InventoryScreen(),    // 3 – inventory
      const SizeRunScreen(),      // 4 – size runs
      ListeProduitsScreen(        // 5 – products list
        onAddProduct: () => setState(() => _selectedIndex = 6),
      ),
      const AjouterProduitScreen(),// 6 – add product
      // ── PEOPLE ───────────────────────────────────────────────────────
      const GestionClientsScreen(),    // 7 – clients
      const GestionFournisseursScreen(), // 8 – suppliers
      const GestionEmployesScreen(),   // 9 – employees
      // ── PURCHASES ────────────────────────────────────────────────────
      const AchatFournisseurScreen(),  // 10 – purchases
      const PurchaseOrdersScreen(),    // 11 – purchase orders
      // ── REPORTS ──────────────────────────────────────────────────────
      const SalesHistoryScreen(),      // 12 – sales history
      const ExpensesScreen(),          // 13 – expenses
      const DebtRecoveryScreen(),      // 14 – recovery
      const ActivityLogsScreen(),      // 15 – activity
      const HealthScreen(),            // 16 – health
    ];

    // Start live clock
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminEmail =
        Supabase.instance.client.auth.currentUser?.email?.split('@').first ??
            'Admin';
    final initials =
        adminEmail.isNotEmpty ? adminEmail[0].toUpperCase() : 'A';

    return Scaffold(
      backgroundColor: _AdminPalette.sidebarBg,
      body: Row(
        children: [
          // ── Sidebar ─────────────────────────────────────────────────
          _buildSidebar(adminEmail, initials),
          // ── Main content ─────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                const OfflineBanner(),
                _buildHeader(),
                Expanded(
                  child: Container(
                    color: AppColors.desktopBackground,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _screens[_selectedIndex],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar ─────────────────────────────────────────────────────────────
  Widget _buildSidebar(String adminEmail, String initials) {
    return Container(
      width: 260,
      color: _AdminPalette.sidebarBg,
      child: Column(
        children: [
          // Brand header
          _buildBrandHeader(adminEmail, initials),

          // Nav groups with scroll + fade hint
          Expanded(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 10),
                  children: _buildNavGroups(),
                ),
                // Bottom fade hint – shows the user there's more below
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _AdminPalette.sidebarBg.withValues(alpha: 0),
                            _AdminPalette.sidebarBg.withValues(alpha: 0.95),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _AdminPalette.textMuted,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom actions
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(String adminEmail, String initials) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _AdminPalette.divider, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo + brand
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _AdminPalette.goldLight,
                  border: Border.all(
                    color: _AdminPalette.gold.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: _AdminPalette.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEPZONE',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _AdminPalette.textPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'ERP · Gestion',
                    style: TextStyle(
                      fontSize: 11,
                      color: _AdminPalette.gold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Admin user chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _AdminPalette.chipBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _AdminPalette.divider,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _AdminPalette.gold,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F1A2E),
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
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _AdminPalette.textPrimary,
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
                              color: _AdminPalette.online,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            S.t('label_role_admin'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: _AdminPalette.gold,
                              fontWeight: FontWeight.w500,
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
    );
  }

  List<Widget> _buildNavGroups() {
    final flatItems = _flatItems;
    int flatIndex = 0;
    final widgets = <Widget>[];

    for (final group in _groups) {
      // Group label
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(
              left: 8, top: 16, bottom: 6),
          child: Text(
            // TODO: use S.t(group.titleKey) when you add the keys
            _groupLabel(group.titleKey),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _AdminPalette.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );

      for (final item in group.items) {
        final idx = flatIndex;
        widgets.add(_buildNavItem(
          idx,
          item.icon,
          item.selectedIcon,
          // TODO: use S.t(item.labelKey)
          S.t(item.labelKey),
          badge: item.badge,
        ));
        flatIndex++;
      }

      // Divider after each group except last
      if (group != _groups.last) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Divider(
              color: _AdminPalette.divider,
              thickness: 1,
              height: 1,
            ),
          ),
        );
      }
    }

    // Extra bottom padding so last item isn't hidden under the fade
    widgets.add(const SizedBox(height: 40));
    return widgets;
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label, {
    int? badge,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 2),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? _AdminPalette.sidebarSelected
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(
                  color: _AdminPalette.gold.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            // Icon box
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isSelected
                    ? _AdminPalette.gold.withValues(alpha: 0.15)
                    : _AdminPalette.divider,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected
                    ? _AdminPalette.gold
                    : _AdminPalette.textMuted,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? _AdminPalette.textPrimary
                      : _AdminPalette.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Badge
            if (badge != null && badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _AdminPalette.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    fontSize: 10,
                    color: _AdminPalette.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            // Selected indicator dot
            if (isSelected && badge == null)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: _AdminPalette.gold.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _AdminPalette.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Notification bell
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.instance.unreadCount,
            builder: (context, count, _) {
              return _FooterIconButton(
                icon: Icons.notifications_outlined,
                badge: count,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          // Language toggle
          const LanguageToggleButton(),
          const Spacer(),
          // Logout
          GestureDetector(
            onTap: () => Supabase.instance.client.auth.signOut(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded,
                      size: 14, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Text(
                    S.t('auth_logout'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Header ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final hour = _now.hour.toString().padLeft(2, '0');
    final min = _now.minute.toString().padLeft(2, '0');
    final sec = _now.second.toString().padLeft(2, '0');
    final dateStr =
        '${_now.day.toString().padLeft(2, '0')}/${_now.month.toString().padLeft(2, '0')}/${_now.year}';

    // Current screen title
    final flatItems = _flatItems;
    final currentLabel = _selectedIndex < flatItems.length
        ? S.t(flatItems[_selectedIndex].labelKey)
        : '';

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _AdminPalette.headerBg,
        border: const Border(
          bottom: BorderSide(color: _AdminPalette.headerBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Current page name
          Text(
            currentLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _AdminPalette.textPrimary,
            ),
          ),

          const Spacer(),

          // ── Stat chips ─────────────────────────────────────────────
          // Low stock alert
          if (_lowStockCount > 0)
            _HeaderChip(
              icon: Icons.warning_amber_rounded,
              label:
                  // TODO: replace _lowStockCount with real query result
                  '$_lowStockCount ${S.t('header_low_stock')}',
              iconColor: Colors.orange,
              textColor: Colors.orange,
            ),

          const SizedBox(width: 8),

          // Today's sales
          _HeaderChip(
            icon: Icons.trending_up_rounded,
            // TODO: replace _todaySales with real Supabase query
            label:
                '${_formatAmount(_todaySales)} DZD',
            iconColor: _AdminPalette.gold,
            textColor: _AdminPalette.gold,
          ),

          const SizedBox(width: 8),

          // Transaction count
          _HeaderChip(
            icon: Icons.receipt_outlined,
            // TODO: replace _todayTransactions with real query
            label: '$_todayTransactions ${S.t('header_transactions')}',
            iconColor: _AdminPalette.textMuted,
            textColor: _AdminPalette.textMuted,
          ),

          const SizedBox(width: 8),

          // Store name
          _HeaderChip(
            icon: Icons.store_outlined,
            // TODO: replace _currentStoreName with real store from user session
            label: _currentStoreName,
            iconColor: _AdminPalette.textMuted,
            textColor: _AdminPalette.textPrimary,
          ),

          const SizedBox(width: 8),

          // Connection status
          _HeaderChip(
            icon: _isOnline
                ? Icons.wifi_rounded
                : Icons.wifi_off_rounded,
            // TODO: replace _isOnline with real connectivity stream
            label: _isOnline
                ? S.t('header_online')
                : S.t('header_offline'),
            iconColor:
                _isOnline ? _AdminPalette.online : _AdminPalette.offline,
            textColor:
                _isOnline ? _AdminPalette.online : _AdminPalette.offline,
          ),

          const SizedBox(width: 8),

          // Date
          _HeaderChip(
            icon: Icons.calendar_today_outlined,
            label: dateStr,
            iconColor: _AdminPalette.textMuted,
            textColor: _AdminPalette.textMuted,
          ),

          const SizedBox(width: 8),

          // Live clock
          _HeaderChip(
            icon: Icons.access_time_rounded,
            label: '$hour:$min:$sec',
            iconColor: _AdminPalette.textMuted,
            textColor: _AdminPalette.textPrimary,
          ),

          const SizedBox(width: 12),

          // Notification bell in header
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.instance.unreadCount,
            builder: (context, count, _) {
              return _FooterIconButton(
                icon: Icons.notifications_outlined,
                badge: count,
                color: _AdminPalette.textMuted,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _groupLabel(String key) {
    // TODO: replace with S.t(key) once you add translation keys:
    // nav_group_main, nav_group_inventory, nav_group_people,
    // nav_group_purchases, nav_group_reports
    const map = {
      'nav_group_main': 'PRINCIPAL',
      'nav_group_inventory': 'INVENTAIRE',
      'nav_group_people': 'PERSONNES',
      'nav_group_purchases': 'ACHATS',
      'nav_group_reports': 'RAPPORTS',
    };
    return map[key] ?? key.toUpperCase();
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;

  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _AdminPalette.chipBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _AdminPalette.divider,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterIconButton extends StatelessWidget {
  final IconData icon;
  final int badge;
  final Color? color;
  final VoidCallback onTap;

  const _FooterIconButton({
    required this.icon,
    this.badge = 0,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _AdminPalette.chipBg,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: _AdminPalette.divider, width: 1),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color ?? _AdminPalette.textMuted,
            ),
          ),
          if (badge > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
