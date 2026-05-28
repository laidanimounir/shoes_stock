import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'views/auth/login_screen.dart';
import 'views/desktop/admin_main_layout.dart';
import 'views/desktop/employee_main_layout.dart';
import 'views/mobile/owner_dashboard.dart';
import 'views/mobile/employee_dashboard.dart';
import 'core/app_session.dart';
import 'core/connectivity_service.dart';
import 'services/inactivity_timer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jluuobtzylejiahbelgp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpsdXVvYnR6eWxlamlhaGJlbGdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3Mjg0NTksImV4cCI6MjA4ODMwNDQ1OX0.ziUtvEdXw3w0yqPpRwk6-rWrIi1qVTKpkZFcxyl7gRE',
  );

  await AppSession.loadLocale();

  runApp(const GestionStockApp());
}

class GestionStockApp extends StatelessWidget {
  const GestionStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppSession.locale,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          title: 'ShoeStock ERP',
          debugShowCheckedModeBanner: false,
          locale: Locale(currentLocale),
          supportedLocales: const [
            Locale('ar'),
            Locale('fr'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
            useMaterial3: true,
          ),
          home: const AuthGate(),
        );
      },
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
        AppSession.clearSession();
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
      AppSession.setRole(role);

      if (AppSession.currentStoreId != null) {
        try {
          final storeRes = await supabase
              .from('stores')
              .select('max_discount_percent')
              .eq('id', AppSession.currentStoreId!)
              .maybeSingle();
          if (storeRes != null && storeRes['max_discount_percent'] != null) {
            AppSession.maxDiscountPercent = (storeRes['max_discount_percent'] as num).toDouble();
          }
        } catch (_) {}
      }

      final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
                        defaultTargetPlatform == TargetPlatform.macOS ||
                        defaultTargetPlatform == TargetPlatform.linux;

      final isMobile = defaultTargetPlatform == TargetPlatform.android ||
                       defaultTargetPlatform == TargetPlatform.iOS;

      if (!mounted) return;

      if (role == 'owner') {
        if (isDesktop) {
          if (mounted) {
            setState(() {
              _currentScreen = _StartupScreen(
                onNavigate: () {
                  if (mounted) {
                    setState(() {
                      _currentScreen = const AdminMainLayout();
                      _isLoading = false;
                    });
                  }
                },
              );
              _isLoading = false;
            });
          }
        } else {
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
          if (mounted) {
            setState(() {
              _currentScreen = _StartupScreen(
                onNavigate: () {
                  if (mounted) {
                    setState(() {
                      _currentScreen = const EmployeeDashboard();
                      _isLoading = false;
                    });
                  }
                },
              );
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _currentScreen = _StartupScreen(
                onNavigate: () {
                  if (mounted) {
                    setState(() {
                      _currentScreen = const EmployeeMainLayout();
                      _isLoading = false;
                    });
                  }
                },
              );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent)) 
          : InactivityTimer(child: _currentScreen),
    );
  }
}

/// Professional startup screen shown briefly after login.
/// Initializes connectivity, displays the detected mode, then navigates in.
class _StartupScreen extends StatefulWidget {
  final VoidCallback onNavigate;
  const _StartupScreen({required this.onNavigate});

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  String _status = 'Initialisation...';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await ConnectivityService.instance.initialize();
    if (!mounted) return;
    setState(() {
      _status = ConnectivityService.instance.isOnline
          ? 'En ligne'
          : 'Hors ligne';
    });
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    widget.onNavigate();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ConnectivityService.instance.isOnline;
    const gold = Color(0xFFD4A843);
    const dark = Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: dark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_rounded, color: gold, size: 64),
            const SizedBox(height: 16),
            Text(
              'STEPZONE',
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'LUXURY SHOES',
              style: GoogleFonts.raleway(
                color: gold,
                fontSize: 10,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isOnline
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOnline ? Colors.greenAccent : Colors.orangeAccent,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _status,
                    style: GoogleFonts.raleway(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
