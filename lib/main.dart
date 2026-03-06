import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'views/auth/login_screen.dart';
import 'views/desktop/admin_main_layout.dart';
import 'views/desktop/employee_main_layout.dart';
import 'views/mobile/owner_dashboard.dart';

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
          .select('role')
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
      
      final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
                        defaultTargetPlatform == TargetPlatform.macOS ||
                        defaultTargetPlatform == TargetPlatform.linux;
                        
      final isMobile = defaultTargetPlatform == TargetPlatform.android ||
                       defaultTargetPlatform == TargetPlatform.iOS;

      if (!mounted) return;

      if (role == 'owner') {
        setState(() {
          _currentScreen = isDesktop ? const AdminMainLayout() : const OwnerDashboard();
          _isLoading = false;
        });
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
          // Employees on Desktop → Employee Layout (POS + products + customers + suppliers + purchases)
          setState(() {
            _currentScreen = const EmployeeMainLayout();
            _isLoading = false;
          });
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
          : _currentScreen,
    );
  }
}
