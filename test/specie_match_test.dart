import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_of_imt/utils/specie_match.dart';

/// A regra de correspondência decide quais espécies o catálogo mostra. Um erro
/// aqui esconde da lista uma serpente que o app identifica, sem erro nenhum na
/// tela — é o tipo de falha que não aparece em teste manual.
void main() {

  group('specieKey normaliza formato', () {

    test('aceita o underscore do classes.json e o espaço do banco', () {
      expect(specieKey('Bothrops_jararaca'), specieKey('Bothrops jararaca'));
    });

    test('ignora caixa e espaço sobrando', () {
      expect(specieKey('  BOTHROPS   JARARACA  '),
          specieKey('Bothrops jararaca'));
    });
  });

  group('specieKey tolera terminação de gênero gramatical', () {

    // O caso real, documentado em SnakeInformationService: o modelo devolve
    // 'Corallus hortulana' e o banco guarda 'Corallus hortulanus'.
    test('casa hortulana com hortulanus', () {
      expect(specieKey('Corallus hortulana'),
          specieKey('Corallus hortulanus'));
    });

    test('casa terminações -a, -us e -um entre si', () {
      final a = specieKey('Genus bicolora');
      expect(specieKey('Genus bicolorus'), a);
      expect(specieKey('Genus bicolorum'), a);
    });
  });

  group('specieKey não confunde espécies diferentes', () {

    test('gêneros diferentes nunca casam', () {
      expect(specieKey('Bothrops jararaca'),
          isNot(specieKey('Crotalus jararaca')));
    });

    test('epítetos de radical diferente não casam', () {
      expect(specieKey('Bothrops jararaca'),
          isNot(specieKey('Bothrops jararacussu')));
    });

    // Sem o piso de radical, 'Micrurus_corallinus' e qualquer epíteto curto
    // virariam fragmentos colidentes.
    test('preserva radical curto em vez de reduzi-lo a nada', () {
      expect(specieKey('Atractus elaps'), 'atractus elaps');
      expect(specieKey('Genus alba'), 'genus alba');
    });
  });

  group('specieKey não quebra com entrada degenerada', () {

    test('nome sem epíteto passa inteiro', () {
      expect(specieKey('Bothrops'), 'bothrops');
    });

    test('string vazia não lança', () {
      expect(specieKey(''), '');
    });
  });
}
