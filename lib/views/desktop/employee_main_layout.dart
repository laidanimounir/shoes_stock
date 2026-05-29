import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../core/app_colors.dart';
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
      const EmployeeDashboardScreen(),
      const PosScreen(),
      ListeProduitsScreen(),
      const InventoryScreen(),
      const GestionClientsScreen(),
      const SalesHistoryScreen(),
      const ActivityLogsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final employeeName =
        Supabase.instance.client.auth.currentUser?.email?.split('@').first ??
            'Employé';
    final initials = employeeName.isNotEmpty
        ? employeeName[0].toUpperCase()
        : S.t('label_role_employee')[0].toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          Container(
            width: 240,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.sidebarTop, AppColors.sidebarBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: BorderDirectional(
                end: BorderSide(
                  color: AppColors.goldLight,
                  width: 0.2,
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
                        color: AppColors.gold.withValues(alpha: 0.2),
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
                                colors: [AppColors.gold, AppColors.goldLight],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: GoogleFonts.playfairDisplay(
                                  color: AppColors.background,
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
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Text(
                          S.t('label_role_employee'),
                          style: GoogleFonts.raleway(
                            color: AppColors.gold,
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
                        _buildNavItem(0, Icons.dashboard_outlined,
                            Icons.dashboard_rounded, S.t('nav_dashboard')),
                        _buildNavItem(1, Icons.point_of_sale_outlined,
                            Icons.point_of_sale_rounded, S.t('nav_pos')),
                        _buildNavItem(2, Icons.inventory_2_outlined,
                            Icons.inventory_2_rounded, S.t('nav_products')),
                        _buildNavItem(3, Icons.inventory_outlined,
                            Icons.inventory_rounded, S.t('nav_inventory')),
                        _buildNavItem(4, Icons.people_outline,
                            Icons.people_rounded, S.t('nav_clients')),
                        _buildNavItem(5, Icons.history_edu_outlined,
                            Icons.history_edu_rounded, S.t('nav_my_sales')),
                        _buildNavItem(6, Icons.history_outlined,
                            Icons.history_rounded, S.t('log_title')),
                      ],
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
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? AppColors.gold : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.raleway(
                color: isSelected ? AppColors.gold : Colors.white60,
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
                  color: AppColors.gold,
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
      builder: (_, _) => Container(
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
