import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../services/user_state.dart';
import '../services/api_service.dart';
import '../services/session_token_cache.dart';
import '../utils/app_snackbar.dart';
import '../theme/lifeverse_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AppSnackBar.show(context, 'Please fill all fields', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.login(email, password);

      if (!mounted) return;

      if (response['success'] == true) {
        final sessionToken = response['sessionToken'] as String?;
        if (sessionToken == null || sessionToken.isEmpty) {
          AppSnackBar.show(
            context,
            'Login succeeded but no session token received',
            isError: true,
          );
          return;
        }

        try {
          await SessionTokenCache.save(sessionToken);
        } catch (_) {
          // Web/desktop cache optional — session still active in memory
        }

        // Load full user profile + app state from MySQL
        Map<String, dynamic> appState = {};
        try {
          final sessionData = await ApiService.validateSession(sessionToken);
          if (sessionData['success'] == true) {
            appState = Map<String, dynamic>.from(sessionData['appState'] ?? {});
          }
        } catch (_) {}

        if (!mounted) return;

        Provider.of<UserState>(context, listen: false).setSession(
          userId: response['userId'] as String,
          sessionToken: sessionToken,
          username: response['username'] as String?,
          fullName: response['fullName'] as String?,
          appState: appState,
        );

        Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
      } else {
        AppSnackBar.show(
          context,
          response['message'] ?? 'Login failed',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Login error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeVerseColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: LifeVerseColors.canvas,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Continue your evolution.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 40),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: LifeVerseColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: LifeVerseColors.line),
                      ),
                      child: Column(
                        children: [
                          _buildTextField(
                            _emailController,
                            "Email Address",
                            Icons.email_outlined,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            _passwordController,
                            "Password",
                            Icons.lock_outline,
                            obscureText: true,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/recovery'),
                              style: TextButton.styleFrom(
                                foregroundColor: LifeVerseColors.primary,
                              ),
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildTactileButton(
                            "Login",
                            _login,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isPasswordVisible = false;

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText && !_isPasswordVisible,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: LifeVerseColors.muted),
        prefixIcon: Icon(icon, color: LifeVerseColors.primary),
        suffixIcon: obscureText
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: LifeVerseColors.muted,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: LifeVerseColors.raised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LifeVerseColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LifeVerseColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LifeVerseColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
    );
  }

  Widget _buildTactileButton(
    String text,
    VoidCallback onPressed, {
    bool isLoading = false,
  }) {
    var isPressed = false;
    return StatefulBuilder(
      builder: (context, setState) {
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) =>
              !isLoading ? setState(() => isPressed = true) : null,
          onPointerUp: (_) {
            if (!isLoading) {
              setState(() => isPressed = false);
              onPressed();
            }
          },
          onPointerCancel: (_) => setState(() => isPressed = false),
          child: AnimatedSlide(
            offset: isPressed ? const Offset(0, 0.03) : Offset.zero,
            duration: const Duration(milliseconds: 100),
            child: AnimatedScale(
              scale: isPressed ? 0.985 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LifeVerseColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: LifeVerseColors.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        text,
                        style: const TextStyle(
                          color: LifeVerseColors.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
