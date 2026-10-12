import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'snake_risk.dart';

/// Um avistamento no mapa, junto com o nível de risco da espécie.
///
/// Existe porque `Marker` não guarda nada além do que o Google Maps desenha:
/// uma vez montado o pino, não há como saber de qual risco ele era. Para
/// filtrar a lista pela legenda é preciso conservar essa informação do lado
/// de fora, e o par evita ter que remontar os ícones a cada toque no filtro —
/// cada pino baixa e desenha a foto da espécie, que é a parte cara do
/// processo.
class SightingMarker {

  final Marker marker;
  final SnakeRisk risk;

  const SightingMarker({
    required this.marker,
    required this.risk,
  });
}
