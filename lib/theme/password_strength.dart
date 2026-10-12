import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../utils/password_rules.dart';
import 'app_theme.dart';

/// Lista de requisitos da senha que marca cada item enquanto a pessoa digita.
///
/// Substitui o modelo de "preencha, envie, receba a lista de erros": aqui o
/// usuário vê o que falta antes de tentar, e cada requisito atendido vira um
/// visto verde na hora.
///
/// Fica oculta enquanto o campo está vazio — mostrar cinco itens vermelhos
/// para quem ainda não digitou nada é hostil e não informa nada.
class PasswordStrength extends StatelessWidget {

  final String password;

  const PasswordStrength({super.key, required this.password});

  @override
  Widget build(BuildContext context) {

    if (password.isEmpty) return const SizedBox.shrink();

    final regras = PasswordRules.all;
    final atendidas = regras.where((r) => r.check(password)).length;
    final total = regras.length;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Barra de progresso: dá a noção de "quanto falta" num relance,
          // antes de a pessoa precisar ler item por item.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: atendidas / total,
              minHeight: 4,
              backgroundColor: const Color(0xFFE8EDE9),
              valueColor: AlwaysStoppedAnimation(
                atendidas == total
                    ? const Color(0xFF2E7D32)
                    : AppColors.accent,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          for (final r in regras) _item(r.key.tr(), r.check(password)),
        ],
      ),
    );
  }

  Widget _item(String texto, bool ok) {
    // Cor nunca sozinha: o ícone muda de forma junto com a cor, para quem não
    // distingue verde de cinza continuar enxergando o que já está atendido.
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.circle_outlined,
            size: 15,
            color: ok ? const Color(0xFF2E7D32) : Colors.black38,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: ok ? const Color(0xFF2E7D32) : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
