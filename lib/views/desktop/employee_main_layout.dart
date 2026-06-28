import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
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

class _Palette {
  _Palette._();
  static const sbBg = Color(0xFF0A0A14);
  static const sbActive = Color(0xFF1A1A35);
  static const sbActiveBorder = Color(0xFFF0A500);
  static const sbText = Color(0xFF9090A8);
  static const sbTextActive = Color(0xFFEEEEFF);
  static const sbSection = Color(0xFF404058);
  static const sbDivider = Color(0xFF1E1E35);
  static const sbIconInactive = Color(0xFF606078);
  static const sbIconActive = Color(0xFFF0A500);

  static const headerBg = Color(0xFF0F0F1C);
  static const headerBorder = Color(0xFF1E1E35);
  static const pagesBg = Color(0xFF0A0A14);

  static const onlineGreen = Color(0xFF4ADE80);
  static const offlineRed = Color(0xFFF87171);
  static const onlineBg = Color(0xFF0D2B1A);
  static const offlineBg = Color(0xFF2B0D0D);
  static const chipBg = Color(0xFF13132A);

  static const badgeRed = Color(0xFFE53935);
  static const avatarBg = Color(0xFF1A1A35);
  static const avatarBorder = Color(0xFFF0A500);
  static const roleBg = Color(0xFF1A1400);
  static const roleText = Color(0xFFF0A500);
}

class EmployeeMainLayout extends StatefulWidget {
  const EmployeeMainLayout({super.key});

  @override
  State<EmployeeMainLayout> createState() => _EmployeeMainLayoutState();
}

class _EmployeeMainLayoutState extends State<EmployeeMainLayout> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;
  bool _sidebarExpanded = false;

  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  final String _currentStoreName = 'AIN DHAB';
  final bool _isOnline = true;

  static const _navGroups = [
    (
      label: 'PRINCIPAL',
      items: [
        (Icons.dashboard_outlined, Icons.dashboard_rounded, 'nav_dashboard'),
        (Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'nav_pos'),
      ],
    ),
    (
      label: 'INVENTAIRE',
      items: [
        (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'nav_products'),
        (Icons.inventory_outlined, Icons.inventory_rounded, 'nav_inventory'),
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
        (Icons.history_outlined, Icons.history_rounded, 'log_title'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      const EmployeeDashboardScreen(),
      const PosScreen(),
      ListeProduitsScreen(),
      const InventoryScreen(),
      const GestionClientsScreen(),
      const SalesHistoryScreen(),
      const ActivityLogsScreen(),
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
    final userEmail =
        Supabase.instance.client.auth.currentUser?.email ?? 'Employé';
    final displayName = userEmail.split('@').first;
    final initials =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'E';

    return Scaffold(
      backgroundColor: _Palette.pagesBg,
      body: Row(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _sidebarExpanded = true),
            onExit: (_) => setState(() => _sidebarExpanded = false),
            child: _buildSidebar(displayName, initials),
          ),
          Container(width: 1, color: const Color(0xFF1E1E35)),
          Expanded(
            child: Column(
              children: [
                const OfflineBanner(),
                _buildHeader(),
                Expanded(
                  child: Container(
                    color: const Color(0xFF0D0D1A),
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

  // ═══════════════════════════════════════════════════════════
  //  SIDEBAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildSidebar(String displayName, String initials) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      clipBehavior: Clip.hardEdge,
      width: _sidebarExpanded ? 220 : 64,
      decoration: const BoxDecoration(color: _Palette.sbBg),
      child: Column(
        children: [
          _buildBrandArea(),
          _buildUserArea(displayName, initials),
          Expanded(child: _buildNavArea()),
          _buildClock(),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildBrandArea() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _Palette.sbDivider)),
      ),
      child: _sidebarExpanded
          ? Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.storefront_rounded,
                    color: _Palette.sbActiveBorder, size: 18),
                const SizedBox(width: 10),
                const Text(
                  'STEPZONE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _Palette.sbTextActive,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            )
          : const Center(
              child: Icon(Icons.storefront_rounded,
                  color: _Palette.sbActiveBorder, size: 18),
            ),
    );
  }

  Widget _buildUserArea(String displayName, String initials) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _Palette.sbDivider)),
      ),
      child: _sidebarExpanded
          ? Row(
              children: [
                _buildAvatar(initials, 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _Palette.sbTextActive,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _Palette.roleBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          S.t('label_role_employee'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _Palette.roleText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(child: _buildAvatar(initials, 40)),
    );
  }

  Widget _buildAvatar(String initials, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _Palette.avatarBg,
        shape: BoxShape.circle,
        border: Border.all(color: _Palette.avatarBorder, width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size > 38 ? 15 : 13,
            fontWeight: FontWeight.w700,
            color: _Palette.sbActiveBorder,
          ),
        ),
      ),
    );
  }

  Widget _buildNavArea() {
    int flatIndex = 0;
    final widgets = <Widget>[];

    for (final group in _navGroups) {
      if (_sidebarExpanded) {
        widgets.add(_buildSectionLabel(group.label));
      }

      for (final item in group.items) {
        final idx = flatIndex;
        widgets.add(_buildNavItem(
          idx,
          item.$1,
          item.$2,
          S.t(item.$3),
        ));
        flatIndex++;
      }

      if (_sidebarExpanded && group != _navGroups.last) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(
              color: _Palette.sbDivider,
              thickness: 1,
              height: 1,
            ),
          ),
        );
      }
    }

    widgets.add(SizedBox(height: _sidebarExpanded ? 16 : 4));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: widgets,
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 10, bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _Palette.sbSection,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData selectedIcon,
      String label) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        clipBehavior: Clip.hardEdge,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? _Palette.sbActive : Colors.transparent,
          borderRadius: isSelected
              ? const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                )
              : BorderRadius.circular(8),
          border: isSelected
              ? const Border(
                  left: BorderSide(color: _Palette.sbActiveBorder, width: 3),
                )
              : null,
        ),
        child: _sidebarExpanded
            ? Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    isSelected ? selectedIcon : icon,
                    size: 18,
                    color: isSelected
                        ? _Palette.sbIconActive
                        : _Palette.sbIconInactive,
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
                            ? _Palette.sbTextActive
                            : _Palette.sbText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              )
            : ClipRect(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Icon(
                      isSelected ? selectedIcon : icon,
                      size: 18,
                      color: isSelected
                          ? _Palette.sbIconActive
                          : _Palette.sbIconInactive,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBadge(int badge) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: _Palette.badgeRed,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$badge',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildClock() {
    final hour = _now.hour.toString().padLeft(2, '0');
    final min = _now.minute.toString().padLeft(2, '0');
    final sec = _now.second.toString().padLeft(2, '0');
    final dateStr =
        '${_now.day.toString().padLeft(2, '0')}/${_now.month.toString().padLeft(2, '0')}';

    final timeStr = _sidebarExpanded ? '$hour:$min:$sec' : '$hour:$min';
    final fontSize = _sidebarExpanded ? 12.0 : 10.0;

    return Container(
      height: 36,
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF1E1E35)),
          bottom: BorderSide(color: Color(0xFF1E1E35)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            timeStr,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFEEEEFF),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (_sidebarExpanded)
            Text(
              dateStr,
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF606078)),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _Palette.sbDivider)),
      ),
      child: _sidebarExpanded
          ? Row(
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: NotificationService.instance.unreadCount,
                  builder: (context, count, _) {
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              const Icon(Icons.notifications_outlined,
                                  color: _Palette.sbText, size: 18),
                              if (count > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: _buildBadge(count),
                                ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 11,
                              color: _Palette.sbText,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                const LanguageToggleButton(),
                const Spacer(),
                GestureDetector(
                  onTap: () => Supabase.instance.client.auth.signOut(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.logout_rounded,
                          size: 18, color: _Palette.offlineRed),
                      const SizedBox(width: 4),
                      const Text(
                        'Déconnexion',
                        style: TextStyle(
                          fontSize: 11,
                          color: _Palette.offlineRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable:
                          NotificationService.instance.unreadCount,
                      builder: (context, count, _) {
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const NotificationsScreen()),
                          ),
                          child: Stack(
                            children: [
                              const Icon(Icons.notifications_outlined,
                                  color: _Palette.sbText, size: 18),
                              if (count > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: _buildBadge(count),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => Supabase.instance.client.auth.signOut(),
                      child: const Icon(Icons.logout_rounded,
                          size: 18, color: _Palette.offlineRed),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader() {
    final allItems = _navGroups.expand((g) => g.items).toList();
    final currentLabel = _selectedIndex < allItems.length
        ? S.t(allItems[_selectedIndex].$3)
        : '';

    final dateStr = _formatDateFr(_now);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: _Palette.headerBg,
        border: Border(
          bottom: BorderSide(color: _Palette.headerBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            currentLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEEEEFF),
            ),
          ),
          const Spacer(),
          _headerChip(
            icon: _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            label: _isOnline ? 'En ligne' : 'Hors ligne',
            bgColor: _isOnline ? _Palette.onlineBg : _Palette.offlineBg,
            textColor:
                _isOnline ? _Palette.onlineGreen : _Palette.offlineRed,
            dotColor:
                _isOnline ? _Palette.onlineGreen : _Palette.offlineRed,
          ),
          const SizedBox(width: 8),
          _headerChip(
            icon: Icons.store_outlined,
            label: _currentStoreName,
            bgColor: _Palette.chipBg,
            textColor: _Palette.sbText,
          ),
          const SizedBox(width: 8),
          _headerChip(
            icon: Icons.calendar_today_outlined,
            label: dateStr,
            bgColor: _Palette.chipBg,
            textColor: _Palette.sbText,
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.instance.unreadCount,
            builder: (context, count, _) {
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                ),
                child: Stack(
                  children: [
                    const Icon(Icons.notifications_outlined,
                        color: _Palette.sbText, size: 20),
                    if (count > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: _buildBadge(count),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          const LanguageToggleButton(),
        ],
      ),
    );
  }

  Widget _headerChip({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    Color? dotColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Palette.sbDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateFr(DateTime d) {
    const days = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
      'Vendredi', 'Samedi', 'Dimanche',
    ];
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
