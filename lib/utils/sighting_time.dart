/// Degrau de uma escala fixa de "visto há X" — não é um timeago genérico
/// (tipo "há 3 dias"), é sempre um dos valores abaixo, arredondado para o
/// mais próximo.
class SightingTimeStep {
  final Duration duration;
  final String translationKey;

  const SightingTimeStep(this.duration, this.translationKey);
}

const List<SightingTimeStep> sightingTimeSteps = [
  SightingTimeStep(Duration(minutes: 15), 'seen_15_min_ago'),
  SightingTimeStep(Duration(hours: 1), 'seen_1_hour_ago'),
  SightingTimeStep(Duration(days: 1), 'seen_1_day_ago'),
  SightingTimeStep(Duration(days: 7), 'seen_1_week_ago'),
  SightingTimeStep(Duration(days: 30), 'seen_1_month_ago'),
  SightingTimeStep(Duration(days: 90), 'seen_3_months_ago'),
  SightingTimeStep(Duration(days: 180), 'seen_6_months_ago'),
  SightingTimeStep(Duration(days: 365), 'seen_1_year_ago'),
];

/// Devolve a chave de tradução (`.tr()`-ready) do degrau mais próximo do
/// tempo decorrido desde [sightedAt]. Não gera texto direto — quem chama
/// decide onde e quando mostrar (ex: só dentro do InfoWindow do marcador).
///
/// Como [sightingTimeSteps] cobre de 15 min a 1 ano, qualquer avistamento
/// mais recente que ~7,5 min cai no primeiro degrau (não existe degrau
/// menor), e qualquer um mais antigo que ~9 meses cai no último (não existe
/// degrau maior que 1 ano).
String sightingTimeAgoKey(DateTime sightedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final elapsed = reference.difference(sightedAt);
  final elapsedMinutes = elapsed.isNegative ? 0 : elapsed.inMinutes;

  var closest = sightingTimeSteps.first;
  var smallestDiff = (elapsedMinutes - closest.duration.inMinutes).abs();

  for (final step in sightingTimeSteps.skip(1)) {
    final diff = (elapsedMinutes - step.duration.inMinutes).abs();
    if (diff < smallestDiff) {
      closest = step;
      smallestDiff = diff;
    }
  }

  return closest.translationKey;
}
