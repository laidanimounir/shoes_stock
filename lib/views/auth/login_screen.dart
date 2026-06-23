import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;


  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(
                child: Text(
                  S.t('auth_fill_fields'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (authResponse.user != null && mounted) {
        // Redirection handled by onAuthStateChange in main.dart
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${S.t('auth_error_invalid')} (${e.message})"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.t('auth_error_generic')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    bool isSending = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(S.t('forgot_password_dialog_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(S.t('forgot_password_instructions')),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: S.t('email'),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.t('cancel_btn')),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty) return;
                      setDialogState(() => isSending = true);
                      try {
                        await Supabase.instance.client.auth
                            .resetPasswordForEmail(email);
                        if (context.mounted) Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(S.t('password_reset_sent')),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } on AuthException catch (e) {
                        setDialogState(() => isSending = false);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text(e.message)),
                          );
                        }
                      } catch (e) {
                        debugPrint('[Login] Password reset error: $e');
                        setDialogState(() => isSending = false);
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(S.t('send_btn')),
            ),
          ],
        ),
      ),
    );
    emailController.dispose();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

 
  // واجهة الهاتف
 
  Widget _buildMobileLayout() {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Language Toggle (Mobile) ──
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              children: [
                TextButton(
                  onPressed: () => AppSession.setLocale('ar'),
                  child: Text('AR',
                      style: GoogleFonts.raleway(
                        color: AppSession.locale.value == 'ar'
                            ? const Color(0xFF00BCD4)
                            : Colors.white70,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                TextButton(
                  onPressed: () => AppSession.setLocale('fr'),
                  child: Text('FR',
                      style: GoogleFonts.raleway(
                        color: AppSession.locale.value == 'fr'
                            ? const Color(0xFF00BCD4)
                            : Colors.white70,
                        fontWeight: FontWeight.bold,
                      )),
                ),
              ],
            ),
          ),
       
          Image.asset(
            'assets/images/login_mobile.jpg',
            fit: BoxFit.cover,
          ),
       
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
      
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
            
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "STEPZONE",
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "LUXURY SHOES",
                          style: GoogleFonts.raleway(
                            color: const Color(0xFFD4A843),
                            fontSize: 12,
                            letterSpacing: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
              
                  Text(
                    S.t('auth_title'),
                    style: GoogleFonts.raleway(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 32),
                
                  _buildMobileField(
                    controller: _emailController,
                    hint: S.t('auth_email'),
                    icon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                
                  _buildMobileField(
                    controller: _passwordController,
                    hint: S.t('auth_password'),
                    icon: Icons.lock_outline,
                    obscure: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 40),
               
                  Center(
                    child: GestureDetector(
                      onTap: _isLoading ? null : _signIn,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00BCD4),
                          shape: BoxShape.circle,
                        ),
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 28,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                 
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        S.t('auth_no_account').toUpperCase(),
                        style: GoogleFonts.raleway(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 32),
                      Text(
                        S.t('auth_forgot_password').toUpperCase(),
                        style: GoogleFonts.raleway(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.raleway(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.raleway(
          color: Colors.white38,
          letterSpacing: 2,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: Colors.white54, size: 18),
        suffixIcon: suffix,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF00BCD4), width: 1.5),
        ),
        filled: false,
      ),
    );
  }


  // واجهة الحاسوب

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
    
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.white,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1A1A2E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Color(0xFFD4A843),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "STEPZONE",
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1A2E),
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                   
                        Text(
                          S.t('auth_login'),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          S.t('auth_welcome_msg'),
                          style: GoogleFonts.raleway(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 36),
                    
                        _buildDesktopLabel(S.t('auth_email')),
                        const SizedBox(height: 6),
                        _buildDesktopField(
                          controller: _emailController,
                          hint: S.t('auth_email'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                
                        _buildDesktopLabel(S.t('auth_password')),
                        const SizedBox(height: 6),
                        _buildDesktopField(
                          controller: _passwordController,
                          hint: S.t('auth_password'),
                          obscure: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey[400],
                              size: 18,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 28),
                   
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4A843),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    S.t('auth_login'),
                                    style: GoogleFonts.raleway(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: Text(
                              S.t('auth_forgot_password'),
                              style: GoogleFonts.raleway(
                                color: const Color(0xFFD4A843),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text.rich(
                            TextSpan(
                              text: S.t('auth_no_account'),
                              style: GoogleFonts.raleway(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                              children: [
                                TextSpan(
                                  text: S.t('auth_register_here'),
                                  style: GoogleFonts.raleway(
                                    color: const Color(0xFF1A1A2E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      
          Expanded(
            flex: 7,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/login_desktop.jpg',
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
          // ── Language Toggle (Desktop) ──
          Positioned(
            top: 20,
            right: 20,
            child: Row(
              children: [
                TextButton(
                  onPressed: () => AppSession.setLocale('ar'),
                  child: Text('AR',
                      style: GoogleFonts.raleway(
                        color: AppSession.locale.value == 'ar'
                            ? const Color(0xFFD4A843)
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                TextButton(
                  onPressed: () => AppSession.setLocale('fr'),
                  child: Text('FR',
                      style: GoogleFonts.raleway(
                        color: AppSession.locale.value == 'fr'
                            ? const Color(0xFFD4A843)
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.raleway(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDesktopField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.raleway(fontSize: 14, color: const Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.raleway(
          color: Colors.grey[400],
          fontSize: 13,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF8F8F6),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(0xFFD4A843),
            width: 1.5,
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
  }
}