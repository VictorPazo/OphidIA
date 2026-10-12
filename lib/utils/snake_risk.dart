/// Classificação de risco a partir do tipo de dentição.
///
/// Vivia dentro de `snake_information.dart`, mas o mapa precisa exatamente da
/// mesma regra para colorir os marcadores, e um utilitário não deve depender de
/// uma tela. Aqui os dois leem da mesma fonte, e a classificação não pode
/// divergir entre uma parte do app e outra.
///
/// A dentição é o critério certo porque descreve o mecanismo: áglifa não tem
/// presa inoculadora, opistóglifa tem presa no fundo da boca e inocula com
/// dificuldade, e solenóglifa e proteróglifa inoculam com eficiência.
library;

enum SnakeRisk { low, medium, high }

String normalizeDentition(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to   = 'aaaaaeeeeiiiiooooouuuuc';
  var out = s.toLowerCase().trim();
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}

bool isAglyphous(String d) => d.contains('aglif') || d.contains('aglyph');

bool isOpisthoglyphous(String d) =>
    d.contains('opistoglif') || d.contains('opisthoglyph');

bool isSolenoOrProtero(String d) =>
    d.contains('solenoglif') ||
    d.contains('proteroglif') ||
    d.contains('solenoglyph') ||
    d.contains('proteroglyph');

/// Devolve null quando a dentição não foi reconhecida — inclusive quando o
/// campo ainda está como "REVISAR" no banco. Nesse caso o app não inventa um
/// nível: simplesmente não mostra classificação.
SnakeRisk? riskFromDentition(String dentition) {
  final d = normalizeDentition(dentition);
  if (isAglyphous(d)) return SnakeRisk.low;
  if (isOpisthoglyphous(d)) return SnakeRisk.medium;
  if (isSolenoOrProtero(d)) return SnakeRisk.high;
  return null;
}
