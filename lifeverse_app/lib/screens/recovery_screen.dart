import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/api_service.dart';
import '../utils/app_snackbar.dart';
import '../theme/lifeverse_theme.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _securityAnswerController =
      TextEditingController();

  bool _isLoading = false;
  bool _isSuccess = false;
  bool _isPasswordVisible = false;

  void _recoverPassword() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final newPassword = _passwordController.text.trim();
    final securityAnswer = _securityAnswerController.text.trim();

    if (email.isEmpty ||
        username.isEmpty ||
        newPassword.isEmpty ||
        securityAnswer.isEmpty) {
      AppSnackBar.show(context, 'Please fill all fields', isError: true);
      return;
    }

    if (newPassword.length < 12 || newPassword.length > 128) {
      AppSnackBar.show(
        context,
        'Password must be 12 to 128 characters',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.recoverPassword(
        email,
        username,
        securityAnswer,
        newPassword,
      );
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() => _isSuccess = true);
        AppSnackBar.show(
          context,
          'Password reset! You can log in now.',
          isSuccess: true,
        );
      } else {
        AppSnackBar.show(
          context,
          response['message'] ?? 'Recovery failed',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Recovery error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _securityAnswerController.dispose();
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  "Recover Identity",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Verify your identity with your security answer to reset your password.",
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
                          if (_isSuccess) ...[
                            const Icon(
                              Icons.check_circle_outline,
                              color: LifeVerseColors.success,
                              size: 80,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Password Reset Successful!",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "You can now log in with your new password.",
                              style: TextStyle(
                                color: LifeVerseColors.muted,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),
                            _buildTactileButton(
                              "Back to Login",
                              () => Navigator.pop(context),
                            ),
                          ] else ...[
                            _buildTextField(
                              _emailController,
                              "Email Address",
                              Icons.email_outlined,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              _usernameController,
                              "Username",
                              Icons.alternate_email,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              _securityAnswerController,
                              "Security Answer",
                              Icons.security_outlined,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              _passwordController,
                              "New Password",
                              Icons.lock_outline,
                              obscureText: true,
                            ),
                            const SizedBox(height: 40),
                            _buildTactileButton(
                              "Reset Password",
                              _recoverPassword,
                              isLoading: _isLoading,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
