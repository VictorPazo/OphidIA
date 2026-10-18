import 'package:flutter_test/flutter_test.dart';
import 'package:snakes_of_imt/models/snake_model.dart';

/// O campo `popular_name_pt` guarda todas as variantes regionais separadas por
/// vírgula, mas a tela só comporta uma. Esta regra decide o que aparece no
/// título da ficha e no cartão do catálogo para as centenas de espécies
/// cadastradas à mão, e um erro aqui se espalha por todas elas de uma vez.
SnakeModel comNomePopular(String? pt) => SnakeModel(
      id: 1,
      family: 'Dipsadidae',
      genus: 'Erythrolamprus',
      specie: 'Erythrolamprus poecilogyrus',
      popularNamePt: pt,
      poisonous: false,
      dentition_type: 'Opistóglifa',
      venomType: 'Não aplicável',
      imageName: '',
    );

void main() {

  group('nome exibido na tela', () {

    test('nome único passa inteiro', () {
      expect(
        comNomePopular('caninana').localizedPopularNameMain('pt'),
        'caninana',
      );
    });

    test('com variantes regionais, exibe só a primeira', () {
      expect(
        comNomePopular('papa-pinto, cobra-verde, jararaquinha')
            .localizedPopularNameMain('pt'),
        'papa-pinto',
      );
    });

    test('ignora espaço sobrando depois da vírgula', () {
      expect(
        comNomePopular('  cobra-d-agua ,  papa-pinto  ')
            .localizedPopularNameMain('pt'),
        'cobra-d-agua',
      );
    });

    test('campo vazio não vira nome', () {
      expect(comNomePopular('').localizedPopularNameMain('pt'), isNull);
      expect(comNomePopular(null).localizedPopularNameMain('pt'), isNull);
    });

    test('REVISAR continua sendo descartado', () {
      expect(comNomePopular('REVISAR').localizedPopularNameMain('pt'), isNull);
    });

    // Vírgula solta no começo era o jeito mais fácil de a tela acabar
    // mostrando um título em branco.
    test('vírgula no início não devolve string vazia', () {
      expect(
        comNomePopular(', papa-pinto').localizedPopularNameMain('pt'),
        isNull,
      );
    });
  });

  group('campo usado pela busca', () {

    test('conserva todas as variantes', () {
      final todas = comNomePopular('papa-pinto, cobra-verde')
          .localizedPopularName('pt');

      expect(todas, 'papa-pinto, cobra-verde');
      expect(todas!.contains('cobra-verde'), isTrue);
    });
  });
}
