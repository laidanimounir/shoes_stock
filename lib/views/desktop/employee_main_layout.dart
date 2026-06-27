

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../shared/widgets/language_toggle_button.dart';
import '../desktop/pos_screen.dart';
import '../admin/liste_produits.dart';
import '../admin/inventory_screen.dart';
import '../admin/gestion_clients.dart';
import '../admin/sales_history_screen.dart';
import '../admin/activity_logs_screen.dart';
import '../admin/employee_dashboard_screen.dart';
import '../../widgets/offline_banner.dart';
import '../../services/notification_service.dart';
import '../admin/notifications_screen.dart';

// ─── Employee Color Palette (Shoe Store – Slate Professional) ──────────────
// Lighter, more neutral than admin. Slate-blue base with teal accent.
// Gives a fieldwork / operational feel vs the admin's executive navy+gold.
class _EmpPalette {
  static const sidebarBg    = Color(0xFF1A2332);
  static const sidebarSelected = Color(0xFF243447);
  static const teal         = Color(0xFF26C6A6);
  static const tealLight    = Color(0x1A26C6A6);
  static const textPrimary  = Color(0xFFDDE3ED);
  static const textMuted    = Color(0xFF6B7C95);
  static const divider      = Color(0xFF243040);
  static const headerBg     = Color(0xFF141C28);
  static const chipBg       = Color(0xFF1E2C3D);
  static const online       = Color(0xFF4CAF50);
  static const offline      = Color(0xFFEF5350);
}

class EmployeeMainLayout extends StatefulWidget {
  const EmployeeMainLayout({super.key});

  @override
  State<EmployeeMainLayout> createState() => _EmployeeMainLayoutState();
}

class _EmployeeMainLayoutState extends State<EmployeeMainLayout> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  // ── Live clock ──────────────────────────────────────────────────────────
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  // ── Hardcoded data – REPLACE WITH REAL SUPABASE QUERIES ────────────────
  // TODO: fetch from stores table using employee's assigned store_id
  final String _currentStoreName = 'AIN DHAB';
  // TODO: replace with real connectivity check
  final bool _isOnline = true;
  // TODO: fetch from sales WHERE date = today AND employee_id = current user
  final double _myTodaySales = 32500.0;
  // TODO: fetch count of today's transactions for this employee only
  final int _myTransactions = 8;

  // ── Nav groups ──────────────────────────────────────────────────────────
  static const _navGroups = [
    (
      label: 'PRINCIPAL',
      items: [
        (Icons.dashboard_outlined,    Icons.dashboard_rounded,      'nav_dashboard'),
        (Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'nav_pos'),
      ],
    ),
    (
      label: 'INVENTAIRE',
      items: [
        (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'nav_products'),
        (Icons.inventory_outlined,   Icons.inventory_rounded,   'nav_inventory'),
      ],
    ),
    (
      label: 'CLIENTS',
      items: [
        (Icons.people_outline, Icons.people_rounded, 'nav_clients'),
      ],
    ),
    (
      label: 'RAPPORTS',
      items: [
        (Icons.history_edu_outlined, Icons.history_edu_rounded, 'nav_my_sales'),
        (Icons.history_outlined,     Icons.history_rounded,     'log_title'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      const EmployeeDashboardScreen(),  // 0 – dashboard
      const PosScreen(),                // 1 – POS
      ListeProduitsScreen(),            // 2 – products
      const InventoryScreen(),          // 3 – inventory
      const GestionClientsScreen(),     // 4 – clients
      const SalesHistoryScreen(),       // 5 – my sales
      const ActivityLogsScreen(),       // 6 – activity log
    ];

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
    final employeeName =
        Supabase.instance.client.auth.currentUser?.email?.split('@').first
        ?? 'Employé';
    final initials = employeeName.isNotEmpty
        ? employeeName[0].toUpperCase()
        : 'E';

    return Scaffold(
      backgroundColor: _EmpPalette.sidebarBg,
      body: Row(
        children: [
          _buildSidebar(employeeName, initials),
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
  Widget _buildSidebar(String employeeName, String initials) {
    return Container(
      width: 240,
      color: _EmpPalette.sidebarBg,
      child: Column(
        children: [
          _buildBrandHeader(employeeName, initials),
          Expanded(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 10),
                  children: _buildNavGroups(),
                ),
                // Bottom fade hint
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _EmpPalette.sidebarBg.withValues(alpha: 0),
                            _EmpPalette.sidebarBg.withValues(alpha: 0.95),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _EmpPalette.textMuted,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(String employeeName, String initials) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _EmpPalette.divider, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _EmpPalette.tealLight,
                  border: Border.all(
                    color: _EmpPalette.teal.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: _EmpPalette.teal,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STEPZONE',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _EmpPalette.textPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    S.t('label_role_employee'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: _EmpPalette.teal,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Employee chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _EmpPalette.chipBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _EmpPalette.divider, width: 1),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _EmpPalette.teal.withValues(alpha: 0.2),
                        border: Border.all(
                          color: _EmpPalette.teal.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _EmpPalette.teal,
                          ),
                        ),
                      ),
                    ),
                    // Pulse dot
                    Positioned(
                      bottom: 0, right: 0,
                      child: _PulseDot(),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _EmpPalette.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        S.t('label_role_employee'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: _EmpPalette.teal,
                          fontWeight: FontWeight.w500,
                        ),
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
    int flatIndex = 0;
    final widgets = <Widget>[];

    for (final group in _navGroups) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 16, bottom: 6),
          child: Text(
            group.label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _EmpPalette.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );

      for (final item in group.items) {
        final idx = flatIndex;
        widgets.add(_buildNavItem(idx, item.$1, item.$2, S.t(item.$3)));
        flatIndex++;
      }

      if (group != _navGroups.last) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(
              color: _EmpPalette.divider,
              thickness: 1,
              height: 1,
            ),
          ),
        );
      }
    }

    widgets.add(const SizedBox(height: 40));
    return widgets;
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData selectedIcon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _EmpPalette.sidebarSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(
                  color: _EmpPalette.teal.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isSelected
                    ? _EmpPalette.teal.withValues(alpha: 0.15)
                    : _EmpPalette.divider,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? _EmpPalette.teal : _EmpPalette.textMuted,
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
                      ? _EmpPalette.textPrimary
                      : _EmpPalette.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: _EmpPalette.teal.withValues(alpha: 0.7),
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
          top: BorderSide(color: _EmpPalette.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.instance.unreadCount,
            builder: (context, count, _) {
              return _EmpIconButton(
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
          const LanguageToggleButton(),
          const Spacer(),
          GestureDetector(
            onTap: () => Supabase.instance.client.auth.signOut(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final hour = _now.hour.toString().padLeft(2, '0');
    final min  = _now.minute.toString().padLeft(2, '0');
    final sec  = _now.second.toString().padLeft(2, '0');
    final dateStr =
        '${_now.day.toString().padLeft(2, '0')}/${_now.month.toString().padLeft(2, '0')}/${_now.year}';

    final allItems = _navGroups.expand((g) => g.items).toList();
    final currentLabel = _selectedIndex < allItems.length
        ? S.t(allItems[_selectedIndex].$3)
        : '';

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _EmpPalette.headerBg,
        border: const Border(
          bottom: BorderSide(color: _EmpPalette.divider, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            currentLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _EmpPalette.textPrimary,
            ),
          ),
          const Spacer(),

          // My sales today (employee sees only their own)
          _EmpChip(
            icon: Icons.trending_up_rounded,
            // TODO: replace with real employee sales query
            label: '${_formatAmount(_myTodaySales)} DZD',
            iconColor: _EmpPalette.teal,
            textColor: _EmpPalette.teal,
          ),
          const SizedBox(width: 8),

          // My transaction count
          _EmpChip(
            icon: Icons.receipt_outlined,
            // TODO: replace with real count query
            label: '$_myTransactions ${S.t('header_transactions')}',
            iconColor: _EmpPalette.textMuted,
            textColor: _EmpPalette.textMuted,
          ),
          const SizedBox(width: 8),

          // Store name
          _EmpChip(
            icon: Icons.store_outlined,
            // TODO: replace with employee's assigned store name
            label: _currentStoreName,
            iconColor: _EmpPalette.textMuted,
            textColor: _EmpPalette.textPrimary,
          ),
          const SizedBox(width: 8),

          // Connection status
          _EmpChip(
            icon: _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            // TODO: replace with real connectivity stream
            label: _isOnline
                ? S.t('header_online')
                : S.t('header_offline'),
            iconColor: _isOnline ? _EmpPalette.online : _EmpPalette.offline,
            textColor: _isOnline ? _EmpPalette.online : _EmpPalette.offline,
          ),
          const SizedBox(width: 8),

          // Date
          _EmpChip(
            icon: Icons.calendar_today_outlined,
            label: dateStr,
            iconColor: _EmpPalette.textMuted,
            textColor: _EmpPalette.textMuted,
          ),
          const SizedBox(width: 8),

          // Live clock
          _EmpChip(
            icon: Icons.access_time_rounded,
            label: '$hour:$min:$sec',
            iconColor: _EmpPalette.textMuted,
            textColor: _EmpPalette.textPrimary,
          ),
          const SizedBox(width: 12),

          // Notification bell
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.instance.unreadCount,
            builder: (context, count, _) {
              return _EmpIconButton(
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
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

// ── Employee-scoped small widgets ──────────────────────────────────────────

class _EmpChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;

  const _EmpChip({
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
        color: _EmpPalette.chipBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _EmpPalette.divider, width: 1),
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

class _EmpIconButton extends StatelessWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;

  const _EmpIconButton({
    required this.icon,
    this.badge = 0,
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
              color: _EmpPalette.chipBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _EmpPalette.divider, width: 1),
            ),
            child: Icon(icon, size: 18, color: _EmpPalette.textMuted),
          ),
          if (badge > 0)
            Positioned(
              right: 4, top: 4,
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

// ── Pulse dot (online indicator) ───────────────────────────────────────────

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
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(
            const Color(0xFF4CAF50),
            const Color(0xFF81C784),
            _anim.value,
          ),
          border: Border.all(color: _EmpPalette.sidebarBg, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50)
                  .withValues(alpha: 0.5 * _anim.value),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}