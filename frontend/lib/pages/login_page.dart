import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session_service.dart';

import 'trips_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String? errorMessage;
  String? successMessage;
  bool isLoading = false;

  // stare vizibilitate parola
  bool isPasswordVisible = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    setState(() {
      errorMessage = null;
      successMessage = null;
    });

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your email.';
      });
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        errorMessage = 'Please enter a valid email address.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your password.';
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final token = await AuthService.login(email: email, password: password);
      await SessionService.setToken(token);

      if (!mounted) return;

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const TripsPage()));
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');

      setState(() {
        if (message == 'Invalid credentials') {
          errorMessage = 'Invalid email or password.';
        } else {
          errorMessage = message;
        }
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const mintSoft = Color(0xFF77CDBB);
    const darkText = Color(0xFF2E2A27);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: mintSoft.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          size: 34,
                          color: darkText,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome back',
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pick up your next journey exactly where you left it.',
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 16),
                      // camp parola
                      TextField(
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                isPasswordVisible = !isPasswordVisible;
                              });
                            },
                            icon: Icon(
                              isPasswordVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (successMessage != null) ...[
                        Text(
                          successMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF2E7D5A),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (errorMessage != null) ...[
                        Text(
                          errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: isLoading ? null : handleLogin,
                          child: Text(isLoading ? 'Loading...' : 'Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
