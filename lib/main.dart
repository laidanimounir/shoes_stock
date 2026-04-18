import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'views/auth/login_screen.dart';
import 'views/desktop/admin_main_layout.dart';
import 'views/desktop/employee_main_layout.dart';
import 'views/mobile/owner_dashboard.dart';
import 'core/app_session.dart';
import 'core/connectivity_service.dart';
import 'local_db/seed_service.dart';
import 'local_db/isar_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jluuobtzylejiahbelgp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpsdXVvYnR6eWxlamlhaGJlbGdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3Mjg0NTksImV4cCI6MjA4ODMwNDQ1OX0.ziUtvEdXw3w0yqPpRwk6-rWrIi1qVTKpkZFcxyl7gRE',
  );

  runApp(const GestionStockApp());
}

class GestionStockApp extends StatelessWidget {
  const GestionStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion de Stock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  Widget _currentScreen = const Center(child: CircularProgressIndicator());

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      final event = data.event;

      if (event == AuthChangeEvent.signedOut || session == null) {
        if (mounted) {
          setState(() {
            _currentScreen = const LoginScreen();
            _isLoading = false;
          });
        }
        return;
      }

      // User logged in, check role
      await _handleRouting(session.user.id);
    });
  }

  Future<void> _handleRouting(String userId) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await supabase
          .from('user_profiles')
          .select('role, store_id')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // No profile found, force sign out with a clear message
        await supabase.auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Profil utilisateur introuvable. Contactez l'administrateur."),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final role = response['role'] as String;

      // ── Set AppSession global state ──
      AppSession.currentUserId = userId;
      AppSession.currentStoreId = response['store_id'] as String?;

      final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
                        defaultTargetPlatform == TargetPlatform.macOS ||
                        defaultTargetPlatform == TargetPlatform.linux;

      final isMobile = defaultTargetPlatform == TargetPlatform.android ||
                       defaultTargetPlatform == TargetPlatform.iOS;

      if (!mounted) return;

      if (role == 'owner') {
        if (isDesktop) {
          // Show mode selection dialog before navigating
          await _showModeDialog();
          if (mounted) {
            setState(() {
              _currentScreen = const AdminMainLayout();
              _isLoading = false;
            });
          }
        } else {
          AppSession.isOfflineMode = false;
          await ConnectivityService.instance.initialize();
          if (mounted) {
            setState(() {
              _currentScreen = const OwnerDashboard();
              _isLoading = false;
            });
          }
        }
      } else if (role == 'employee') {
        if (isMobile) {
          // Force sign out and show exact requested error message
          await supabase.auth.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Accès refusé : Mobile réservé au Propriétaire.",
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          // Show mode selection dialog before navigating
          await _showModeDialog();
          if (mounted) {
            setState(() {
              _currentScreen = const EmployeeMainLayout();
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      // In case of error (e.g. no internet), show login or error
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentScreen = const LoginScreen();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de connexion : Impossible de vérifier le profil. Veuillez vérifier votre internet."),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════
  // Mode Selection Dialog
  // ══════════════════════════════════════════
  Future<void> _showModeDialog() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (ctx) => _ModeSelectionDialog(),
    );
    // If dismissed (tap outside) → defaults to online mode
    if (AppSession.isOfflineMode == false) {
      await ConnectivityService.instance.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent)) 
          : _currentScreen,
    );
  }
}

class _ModeSelectionDialog extends StatefulWidget {
  @override
  State<_ModeSelectionDialog> createState() => _ModeSelectionDialogState();
}

class _ModeSelectionDialogState extends State<_ModeSelectionDialog> {
  bool _isSeeding = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final gold = const Color(0xFFD4A843);
    final dark = const Color(0xFF1A1A2E);

    return Dialog(
      backgroundColor: dark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: gold, width: 0.5)),
      child: Container(
        padding: const EdgeInsets.all(32),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Choisir le mode",
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            if (!_isSeeding) ...[
              _buildOption(
                icon: Icons.public,
                title: "En ligne",
                subtitle: "Accès temps réel (Recommandé)",
                onTap: () {
                  AppSession.isOfflineMode = false;
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              _buildOption(
                icon: Icons.cloud_off,
                title: "Hors ligne",
                subtitle: "Travailler sans internet",
                onTap: _handleOfflineChoice,
              ),
            ] else ...[
              const CircularProgressIndicator(color: Color(0xFFD4A843)),
              const SizedBox(height: 20),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: GoogleFonts.raleway(color: Colors.white70, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final gold = const Color(0xFFD4A843);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: gold, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.raleway(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: GoogleFonts.raleway(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Future<void> _handleOfflineChoice() async {
    setState(() {
      _isSeeding = true;
      _status = "Initialisation de la base locale...";
    });

    try {
      await IsarService.getInstance();
      final isSeeded = await SeedService.instance.isSeeded();

      if (!isSeeded) {
        if (AppSession.currentStoreId == null) {
          setState(() => _status = "Erreur: Aucun magasin assigné.");
          await Future.delayed(const Duration(seconds: 2));
          setState(() => _isSeeding = false);
          return;
        }
        setState(() => _status = "Synchronisation initiale en cours...");
        await SeedService.instance.seedAll(AppSession.currentStoreId!);
      } else {
        setState(() => _status = "Données locales disponibles ✓");
        await Future.delayed(const Duration(milliseconds: 800));
      }

      AppSession.isOfflineMode = true;
      await ConnectivityService.instance.initialize();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _status = "Erreur: $e");
      await Future.delayed(const Duration(seconds: 3));
      setState(() => _isSeeding = false);
    }
  }
}
