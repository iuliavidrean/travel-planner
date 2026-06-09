import 'package:flutter/material.dart';

import 'login_page.dart';

import 'register_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const mintSoft = Color(0xFF77CDBB);

    return Scaffold(
      appBar: AppBar(title: const Text('TerraWise')),
      body: Center(
        child: SizedBox(
          width: 460,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: Color(0xFFEDEDED)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Home page icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: mintSoft.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.travel_explore_rounded,
                        size: 36,
                        color: Color(0xFF2F2F2F),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Home page titlu
                    Text(
                      'Plan your trips smarter',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Home page subtitlu
                    Text(
                      'Create trips, generate itineraries, view your plan by day, and export everything easily.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Buton Login
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Buton Register
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text('Register'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
