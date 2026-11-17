import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/api_service.dart';
import '../utils/app_snackbar.dart';
import '../theme/lifeverse_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _securityAnswerController =
      TextEditingController();
  bool _isLoading = false;
  String _selectedQuestion = 'What was your childhood nickname?';

  final List<String> _securityQuestions = [
    'What was your childhood nickname?',
    'What is the name of your favorite childhood friend?',
    'What city were you born in?',
    'What is your mother\'s maiden name?',
    'What was the name of your first pet?',
  ];

  void _register() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final securityAnswer = _securityAnswerController.text.trim();

    if (name.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        securityAnswer.isEmpty) {
      AppSnackBar.show(context, 'Please fill all fields', isError: true);
      return;
    }

    if (password.length < 12 || password.length > 128) {
      AppSnackBar.show(
        context,
        'Password must be 12 to 128 characters',
        isError: true,
      );
      return;
    }

    if (!email.contains('@')) {
      AppSnackBar.show(
        context,
        'Please enter a valid email address',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.register(
        name,
        email,
        username,
        password,
        _selectedQuestion,
        securityAnswer,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        AppSnackBar.show(
          context,
          response['message'] ?? 'Account created! Please log in.',
          isSuccess: true,
        );
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;

        Navigator.pushReplacementNamed(context, '/permissions');
      } else {
        AppSnackBar.show(
          context,
          response['message'] ?? 'Registration failed',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Registration error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
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
                  "Create Identity",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Join the LifeVerse.",
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
                            _nameController,
                            "Full Name",
                            Icons.person_outline,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            _usernameController,
                            "Username",
                            Icons.alternate_email,
                          ),
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 20),

                          // Security Question Dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: LifeVerseColors.raised,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: LifeVerseColors.line,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedQuestion,
                                isExpanded: true,
                                dropdownColor: LifeVerseColors.surface,
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: LifeVerseColors.primary,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedQuestion = newValue!;
                                  });
                                },
                                items: _securityQuestions
                                    .map<DropdownMenuItem<String>>((
                                      String value,
                                    ) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    })
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            _securityAnswerController,
                            "Security Answer",
                            Icons.security_outlined,
                          ),
                          const SizedBox(height: 40),
                          _buildTactileButton(
                            "Register",
                            _register,
                            isLoading: _isLoading,
                          ),
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
