import 'dart:io' show exit;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'views/auth/login_screen.dart';
import 'views/desktop/admin_main_layout.dart';
import 'views/desktop/employee_main_layout.dart';
import 'views/mobile/owner_dashboard.dart';
import 'views/mobile/employee_dashboard.dart';
import 'core/app_session.dart';
import 'core/connectivity_service.dart';
import 'core/api_version_service.dart';
import 'services/inactivity_timer.dart';
import 'services/notification_service.dart';
import 'views/auth/pin_lock_screen.dart';
import 'local_db/isar_service.dart';
import 'local_db/collections/settings_local.dart';

/// Used for exit() call — on web this is a no-op
void _exitApp(int code) {
  if (kIsWeb) return;
  exit(code);
}

Future<void> main() async {
  final sentryDsn = const String.fromEnvironment('SENTRY_DSN');

  if (!kIsWeb && sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 1.0;
        options.enableAppLifecycleBreadcrumbs = true;
        options.beforeSend = (event, hint) {
          if (AppSession.currentUserId != null || AppSession.currentStoreId != null) {
            event = event.copyWith(
              user: event.user?.copyWith(
                id: AppSession.currentUserId,
                data: {
                  if (AppSession.currentStoreId != null) 'store_id': AppSession.currentStoreId,
                },
              ),
            );
          }
          return event;
        };
      },
      appRunner: () => _runApp(),
    );
  } else {
    await _runApp();
  }
}

String? _appCurrentVersion;
String? _appLatestVersion;
ApiVersionInfo? _apiVersionInfo;

Future<void> _checkVersion() async {
  try {
    final pkg = await PackageInfo.fromPlatform();
    _appCurrentVersion = pkg.version;
    _apiVersionInfo = await ApiVersionService.instance.checkVersion();
    _appLatestVersion = _apiVersionInfo?.latestVersion ?? _apiVersionInfo?.version;
  } catch (e, stackTrace) {
    debugPrint('[Main] Version check error: $e');
    debugPrint('[Main] StackTrace: $stackTrace');
  }
}

Future<void> _runApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Sentry.captureException(
      details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
    return true;
  };

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jluuobtzylejiahbelgp.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpsdXVvYnR6eWxlamlhaGJlbGdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3Mjg0NTksImV4cCI6MjA4ODMwNDQ1OX0.ziUtvEdXw3w0yqPpRwk6-rWrIi1qVTKpkZFcxyl7gRE',
  );

  assert(supabaseUrl.isNotEmpty, 'SUPABASE_URL is not set. Run with --dart-define or use launch.json');
  assert(supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY is not set.');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await AppSession.loadLocale();

  await _checkVersion();

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
  bool _loadingTimedOut = false;
  bool _pinEnabled = false;
  Widget _currentScreen = const Center(child: CircularProgressIndicator());

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _loadingTimeout();
    _loadPinSetting();
  }

  Future<void> _loadPinSetting() async {
    try {
      final isar = await IsarService.getInstance();
      final settings = await isar.settingsLocals.get(1);
      if (mounted) setState(() => _pinEnabled = settings?.pinEnabled ?? false);
    } catch (e, stackTrace) {
      debugPrint('[Main] PIN setting load error: $e');
      debugPrint('[Main] StackTrace: $stackTrace');
    }
  }

  void _loadingTimeout() {
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isLoading && !_loadingTimedOut) {
        _loadingTimedOut = true;
        setState(() {
          _currentScreen = const LoginScreen();
          _isLoading = false;
        });
      }
    });
  }

  void _setupAuthListener() {
    supabase.auth.onAuthStateChange.listen(
      (data) async {
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

        await _handleRouting(session.user.id);
      },
      onError: (error) {
        debugPrint('Auth error: $error');
        Supabase.instance.client.auth.signOut();
        AppSession.clearSession();
        if (mounted) {
          setState(() {
            _currentScreen = const LoginScreen();
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _handleRouting(String userId) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await supabase
          .from('user_profiles')
          .select('role, store_id, preferred_language')
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

      NotificationService.instance.startPolling();

      final prefLang = response['preferred_language'] as String?;
      if (prefLang != null && prefLang.isNotEmpty) {
        AppSession.setLocale(prefLang);
      }

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
        } catch (e, stackTrace) {
          debugPrint('[Main] Max discount fetch error: $e');
          debugPrint('[Main] StackTrace: $stackTrace');
        }
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
    Widget body = _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent)) 
        : _currentScreen;
    if (!_isLoading && _currentScreen is! LoginScreen && _pinEnabled) {
      body = PinLockScreen(child: body);
    }
    return Scaffold(
      body: InactivityTimer(child: body),
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

    final current = _appCurrentVersion;
    final info = _apiVersionInfo;
    final latestVer = _appLatestVersion;

    if (info != null && current != null) {
      if (ApiVersionService.instance.isMinFlutterVersionExceeded(info, current)) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Mise à jour requise'),
              content: Text('Votre version ($current) est obsolète. Veuillez mettre à jour vers la version ${info.minFlutterVersion} ou supérieure.'),
              actions: [
                ElevatedButton(
                  onPressed: () => _exitApp(0),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text('Fermer l\'application'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (info.deprecated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cette version est dépréciée. Veuillez mettre à jour dès que possible.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    }

    if (mounted) widget.onNavigate();

    if (current != null && latestVer != null && ApiVersionService.instance.compareVersions(current, latestVer) < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Une nouvelle version ($latestVer) est disponible sur le Play Store.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.blue,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
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
