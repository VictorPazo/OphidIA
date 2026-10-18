import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Abre uma imagem em tela cheia, com pinça para aproximar e arrastar.
///
/// Nasceu como o visualizador das dentições, na ficha. Virou componente
/// quando as fotos das serpentes passaram a abrir do mesmo jeito: a ficha, o
/// histórico e o catálogo usam este mesmo código, e o gesto é o mesmo em
/// qualquer tela do app.
///
/// [heroTag], quando informado, faz a imagem crescer a partir de onde estava
/// em vez de surgir do nada. Ele precisa ser o mesmo tag do `Hero` que envolve
/// a miniatura na tela de origem.
void openImageViewer(
  BuildContext context, {
  required ImageProvider image,
  required String title,
  Object? heroTag,
  bool italicTitle = false,
}) {

  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,

      // Sem transição própria: quem anima é o Hero da imagem, saindo da
      // miniatura e crescendo até a tela cheia.
      transitionDuration: const Duration(milliseconds: 250),

      pageBuilder: (context, animation, secondaryAnimation) {

        Widget foto = InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image(
            image: image,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        );

        if (heroTag != null) {
          foto = Hero(tag: heroTag, child: foto);
        }

        return Scaffold(
          backgroundColor: Colors.transparent,

          body: SafeArea(
            child: Stack(
              children: [

                // Toque em qualquer lugar fora da imagem fecha — é o gesto
                // que as pessoas tentam primeiro.
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),

                Center(child: foto),

                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontStyle: italicTitle ? FontStyle.italic : null,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        color: Colors.white,
                        tooltip: "close".tr(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Selo de lupa no canto de uma imagem que abre ampliada.
///
/// Sem um sinal visível ninguém descobre que a imagem abre: tocar em foto não
/// é gesto óbvio numa tela de leitura.
class ZoomBadge extends StatelessWidget {

  final double size;

  const ZoomBadge({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size <= 14 ? 2 : AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(size <= 14 ? 6 : 8),
      ),
      child: Icon(
        Icons.zoom_in,
        size: size,
        color: Colors.white,
      ),
    );
  }
}
