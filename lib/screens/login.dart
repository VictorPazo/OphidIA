import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens.dart';
import '../services/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();

  final TextEditingController senhaController = TextEditingController();

  bool visualizarSenha = false;

  bool isLoggingIn = false;

  // 🔥 RESETAR SENHA
  Future<void> showResetPasswordDialog() async {
    final TextEditingController resetEmailController = TextEditingController();

    showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: Text("reset_password".tr()),

          content: TextField(
            controller: resetEmailController,

            decoration: InputDecoration(labelText: "email".tr()),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: Text("cancel".tr()),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.background,
              ),

              onPressed: () async {
                try {
                  await Supabase.instance.client.auth.resetPasswordForEmail(
                    resetEmailController.text,

                    redirectTo: 'https://victorpazo.github.io/OphidIA/auth/redefinir-senha.html',
                  );

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("reset_email_sent".tr())),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },

              child: Text(
                "send".tr(),

                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),

              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 80),

                    Image.asset(
                      'assets/UI-UX/logo.png',

                      width: 80,
                      height: 80,

                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // 👋 TITULO
                    Text(
                      "welcome".tr(),

                      style: AppTextStyles.screenTitle,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // 📄 SUBTITULO
                    Text(
                      "login_subtitle".tr(),

                      textAlign: TextAlign.center,

                      style: const TextStyle(
                        color: AppColors.onBackgroundMuted,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // 🔲 CARD LOGIN
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),

                        decoration: const BoxDecoration(
                          color: Colors.white,

                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(25),
                          ),
                        ),

                        child: Column(
                          children: [
                            // 📧 EMAIL
                            TextField(
                              controller: emailController,

                              decoration: InputDecoration(
                                labelText: "email".tr(),

                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // 🔒 SENHA
                            TextField(
                              controller: senhaController,

                              obscureText: !visualizarSenha,

                              decoration: InputDecoration(
                                labelText: "password".tr(),

                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),

                                suffixIcon: IconButton(
                                  icon: Icon(
                                    visualizarSenha
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),

                                  onPressed: () {
                                    setState(() {
                                      visualizarSenha = !visualizarSenha;
                                    });
                                  },
                                ),
                              ),
                            ),

                            // 🔥 ESQUECEU SENHA
                            Align(
                              alignment: Alignment.centerRight,

                              child: TextButton(
                                onPressed: () {
                                  showResetPasswordDialog();
                                },

                                child: Text(
                                  "forgot_password".tr(),

                                  style: const TextStyle(
                                    color: AppColors.background,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: AppSpacing.sm),

                            // 🔥 LOGIN
                            SizedBox(
                              width: double.infinity,

                              child: ElevatedButton(
                                onPressed: isLoggingIn
                                    ? null
                                    : () async {
                                        setState(() {
                                          isLoggingIn = true;
                                        });

                                        final authService = AuthService();

                                        final erro = await authService.login(
                                          email: emailController.text,

                                          senha: senhaController.text,
                                        );

                                        if (!mounted) return;

                                        setState(() {
                                          isLoggingIn = false;
                                        });

                                        if (erro == null) {
                                          Navigator.pushReplacement(
                                            context,

                                            AppPageRoute(
                                              builder: (_) => const HomePage(),
                                              transition: AppTransition.fade,
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(erro)),
                                          );
                                        }
                                      },

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.background,
                                ),

                                child: isLoggingIn
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,

                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        "login".tr(),

                                        style: AppTextStyles.buttonLabel,
                                      ),
                              ),
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // 🆕 CRIAR CONTA
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,

                                  AppPageRoute(
                                    builder: (_) => const CadastroPage(),
                                    transition: AppTransition.slide,
                                  ),
                                );
                              },

                              child: Text(
                                "create_account".tr(),

                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
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
          );
        },
      ),
    );
  }
}
