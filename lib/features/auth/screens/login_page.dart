import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/login_notifier.dart';
import 'register_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginNotifier(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    // Usamos Consumer para que la UI se reconstruya solo cuando sea necesario
    return Consumer<LoginNotifier>(
      builder: (context, notifier, child) {
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  const Text(
                    'Iniciar Sesión',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 80),
                  TextField(
                    controller: notifier.emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Correo electrónico',
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: notifier.passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 4.0),
                    horizontalTitleGap: 8.0,
                    leading: Checkbox(
                      value: notifier.rememberMe,
                      onChanged: notifier.handleRememberMe,
                    ),
                    title: const Text("Recordarme al iniciar"),
                    onTap: () => notifier.handleRememberMe(!notifier.rememberMe),
                  ),
                  const SizedBox(height: 32),
                  if (notifier.isLoading)
                    const CircularProgressIndicator()
                  else
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final result = await notifier.signInWithEmail();
                            if (result != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result), backgroundColor: Colors.red),
                              );
                            }
                          },
                          child: const Text('Ingresar'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await notifier.signInWithGoogle();
                            if (result != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result)),
                              );
                            }
                          },
                          icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png', height: 18.0),
                          label: const Text('Ingresar con Google'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RegisterPage()));
                    },
                    child: const Text.rich(
                      TextSpan(
                        text: '¿No tienes cuenta? ',
                        children: [
                          TextSpan(
                            text: 'Regístrate',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: notifier.togglePasswordReset,
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                  if (notifier.showPasswordReset)
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Column(
                        children: [
                          const Text('Ingrese su correo para recuperar la contraseña.'),
                          const SizedBox(height: 10),
                          TextField(
                            controller: notifier.recoveryEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(hintText: 'Correo de recuperación'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: notifier.isLoading
                                ? null
                                : () async {
                              final result = await notifier.sendPasswordResetEmail();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result)),
                                );
                              }
                            },
                            child: const Text('Enviar correo'),
                          )
                        ],
                      ),
                    )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}