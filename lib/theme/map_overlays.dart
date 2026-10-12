import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../utils/snake_marker.dart';
import '../utils/snake_risk.dart';
import 'app_theme.dart';
import 'info_hint.dart';

/// Resumo do que existe em volta do usuário, sobreposto ao topo do mapa.
///
/// Ninguém abre este mapa para contar pinos: a pergunta é "é perigoso aqui?".
/// Uma coleção de marcadores não responde isso, um número responde.
///
/// Fica oculto quando não há nada por perto. Um cartão dizendo "0 avistamentos"
/// ocuparia espaço para informar ausência, e a ausência já é visível no mapa
/// vazio.
class MapProximitySummary extends StatelessWidget {

  final int total;
  final int highRisk;
  final double radiusKm;
  final int days;

  const MapProximitySummary({
    super.key,
    required this.total,
    required this.highRisk,
    required this.radiusKm,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {

    if (total == 0) return const SizedBox.shrink();

    // A linha de apoio muda conforme haja ou não peçonhenta por perto: é a
    // distinção que importa, e repetir a contagem total seria redundante.
    final detalhe = highRisk > 0
        ? "map_nearby_venomous".plural(highRisk)
        : "map_nearby_none_venomous".tr();

    return Container(
      margin: const EdgeInsets.all(AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            highRisk > 0
                ? Icons.warning_amber_rounded
                : Icons.place_outlined,
            size: 20,
            color: highRisk > 0
                ? SnakeMarker.colorFor(SnakeRisk.high)
                : AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "map_nearby_count".plural(total),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  "$detalhe · ${"map_nearby_window".tr(namedArgs: {
                    'km': radiusKm.toStringAsFixed(0),
                    'days': '$days',
                  })}",
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Legenda das cores dos marcadores e filtro do mapa, no rodapé.
///
/// Sem ela as três cores eram adivinhação — e o próprio usuário relatou não
/// saber do que elas falavam. Por isso a palavra "Risco" abre a legenda: três
/// bolinhas com "Alto, Médio, Baixo" não dizem risco de quê.
///
/// Tocar num nível filtra o mapa para ele; tocar de novo desfaz. O filtro
/// mora aqui porque a legenda já é o lugar onde a pessoa olha para entender
/// as cores, e aprender o significado e poder isolar um nível são o mesmo
/// gesto.
///
/// O texto ao lado de cada bolinha também é o que torna a legenda útil para
/// quem não distingue vermelho de verde.
class MapRiskLegend extends StatelessWidget {

  /// Nível isolado no momento, ou null quando o mapa mostra todos.
  final SnakeRisk? selected;

  final ValueChanged<SnakeRisk?> onSelect;

  const MapRiskLegend({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "risk".tr(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _dot(SnakeRisk.high, "risk_high".tr()),
          _dot(SnakeRisk.medium, "risk_medium".tr()),
          _dot(SnakeRisk.low, "risk_low".tr()),
          InfoHint(
            title: "map_legend_info_title".tr(),
            body: "map_legend_info_body".tr(),
            color: Colors.black38,
            size: 15,
          ),
        ],
      ),
    );
  }

  Widget _dot(SnakeRisk risk, String label) {

    final bool ativo = selected == risk;
    final bool algumAtivo = selected != null;

    // Quando um nível está isolado, os outros desbotam em vez de desaparecer:
    // continuam legíveis como legenda e seguem tocáveis para trocar o filtro.
    final double opacidade = !algumAtivo || ativo ? 1 : 0.4;

    return Semantics(
      label: label,
      button: true,
      selected: ativo,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // Tocar no nível já ativo volta a mostrar o mapa inteiro — sem isso
        // não haveria como desfazer o filtro sem sair da tela.
        onTap: () => onSelect(ativo ? null : risk),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 3,
          ),
          child: Opacity(
            opacity: opacidade,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: SnakeMarker.colorFor(risk),
                    shape: BoxShape.circle,
                    // O anel marca o nível isolado sem depender de cor, que
                    // é justamente o que a legenda não pode pressupor.
                    border: ativo
                        ? Border.all(color: Colors.black87, width: 2)
                        : null,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: ativo ? FontWeight.w700 : FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
