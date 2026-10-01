import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_of_imt/utils/sighting_time.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12, 0, 0);

  String keyFor(Duration elapsed) =>
      sightingTimeAgoKey(now.subtract(elapsed), now: now);

  group('sightingTimeAgoKey', () {
    test('agora e qualquer coisa abaixo do primeiro degrau vira 15 min', () {
      expect(keyFor(Duration.zero), 'seen_15_min_ago');
      expect(keyFor(const Duration(minutes: 5)), 'seen_15_min_ago');
      expect(keyFor(const Duration(minutes: 15)), 'seen_15_min_ago');
    });

    test('data no futuro (relógio dessincronizado) nunca quebra', () {
      expect(keyFor(const Duration(minutes: -10)), 'seen_15_min_ago');
    });

    test('arredonda para o degrau mais próximo, não para baixo', () {
      // ponto médio entre 15min e 1h é 37,5min
      expect(keyFor(const Duration(minutes: 36)), 'seen_15_min_ago');
      expect(keyFor(const Duration(minutes: 40)), 'seen_1_hour_ago');
    });

    test('acerta cada degrau exato da escala', () {
      expect(keyFor(const Duration(hours: 1)), 'seen_1_hour_ago');
      expect(keyFor(const Duration(days: 1)), 'seen_1_day_ago');
      expect(keyFor(const Duration(days: 7)), 'seen_1_week_ago');
      expect(keyFor(const Duration(days: 30)), 'seen_1_month_ago');
      expect(keyFor(const Duration(days: 90)), 'seen_3_months_ago');
      expect(keyFor(const Duration(days: 180)), 'seen_6_months_ago');
      expect(keyFor(const Duration(days: 365)), 'seen_1_year_ago');
    });

    test('qualquer coisa além do último degrau continua em 1 ano', () {
      expect(keyFor(const Duration(days: 900)), 'seen_1_year_ago');
      expect(keyFor(const Duration(days: 3650)), 'seen_1_year_ago');
    });

    test('meio do caminho entre dois degraus distantes escolhe o mais perto', () {
      // ponto médio entre 1 semana (7d) e 1 mês (30d) é 18,5 dias
      expect(keyFor(const Duration(days: 18)), 'seen_1_week_ago');
      expect(keyFor(const Duration(days: 19)), 'seen_1_month_ago');
    });
  });
}
