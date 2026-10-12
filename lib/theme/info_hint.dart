import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Ícone de "i" que abre uma explicação curta ao toque.
///
/// Existe para os pontos da ficha em que o termo correto é tecnicamente
/// preciso mas pouco conhecido, e em que uma leitura ingênua leva a conclusão
/// errada. Hoje são dois: a diferença entre peçonhento e venenoso, e o que a
/// porcentagem de confiança realmente significa.
///
/// É um diálogo e não um tooltip de pressionar-e-segurar de propósito: o
/// texto tem várias linhas e precisa ser lido com calma, e o gesto de segurar
/// não é descoberto por quem não o conhece.
class InfoHint extends StatelessWidget {

  final String title;
  final String body;

  /// A cor do ícone muda conforme o fundo: na ficha branca ele é cinza, no
  /// selo verde de confiança precisa ser claro para aparecer.
  final Color color;

  final double size;

  const InfoHint({
    super.key,
    required this.title,
    required this.body,
    this.color = Colors.black45,
    this.size = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkResponse(
        onTap: () => _show(context),

        // O ícone tem 17px, pequeno demais para acertar com o dedo. O raio
        // amplia a área de toque sem aumentar o desenho.
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.info_outline,
            size: size,
            color: color,
          ),
        ),
      ),
    );
  }

  void _show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 22,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("close".tr()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
