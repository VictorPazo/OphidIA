/// Chave de comparação entre o nome de espécie do banco e o do modelo.
///
/// Os dois não escrevem sempre igual. O epíteto latino muda de terminação
/// conforme o gênero gramatical atribuído à espécie, e o GBIF (de onde vêm as
/// fichas) discorda das pastas de treino em alguns casos. O próprio
/// `SnakeInformationService` registra um: o modelo devolve
/// `Corallus hortulana` e o banco guarda `Corallus hortulanus`.
///
/// Comparar nome cru esconderia do catálogo espécies que o modelo reconhece —
/// exatamente o oposto do que o filtro pretende. Então o gênero é comparado
/// inteiro e o epíteto perde a terminação de gênero gramatical antes da
/// comparação.
///
/// A regra é propositalmente permissiva: um falso positivo mostra um cartão a
/// mais no catálogo, enquanto um falso negativo esconde uma espécie que a IA
/// identifica. O primeiro erro custa pouco, o segundo derrota o propósito.
library;

/// Terminações de gênero gramatical do latim, das mais longas para as mais
/// curtas — ordem necessária para que `ae` seja testado antes de `e`, e `us`
/// antes de nada sobrar.
const List<String> _terminacoes = [
  'us', 'um', 'is', 'ii', 'ae', 'i', 'a', 'e',
];

/// Mínimo de letras que o radical precisa conservar. Sem isso, epítetos
/// curtos virariam fragmentos que colidem entre si.
const int _radicalMinimo = 4;

String specieKey(String specie) {

  var limpo = specie
      .toLowerCase()
      .replaceAll('_', ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  final partes = limpo.split(' ');

  // Nome sem epíteto (ou vazio) não tem o que normalizar.
  if (partes.length < 2) return limpo;

  final genero = partes[0];
  var epiteto = partes[1];

  for (final terminacao in _terminacoes) {
    if (epiteto.endsWith(terminacao) &&
        epiteto.length - terminacao.length >= _radicalMinimo) {
      epiteto = epiteto.substring(0, epiteto.length - terminacao.length);
      break;
    }
  }

  return '$genero $epiteto';
}
