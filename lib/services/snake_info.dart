import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/snake_model.dart';

class SnakeInformationService {

  final supabase = Supabase.instance.client;

  // - Se o Supabase confirmar que não existe linha com esse id, a espécie não cadastrada.
  // - Qualquer outro erro (rede, servidor, timeout) sobe como exceção,
  //   pra CameraPage conseguir mostrar a mensagem específica certa.
  Future<SnakeModel?> getSnakeById(int snakeId) async {

    try {

      final response = await supabase
          .from('snakes')
          .select()
          .eq('id', snakeId)
          .single();

      return SnakeModel.fromMap(response);

    } on PostgrestException catch (e) {

      if (e.code == 'PGRST116') {
        return null;
      }
      rethrow;
    }
  }

  /// Todas as espécies cadastradas, em ordem de nome científico.
  ///
  /// Traz as linhas inteiras de uma vez, em vez de paginar: são poucas
  /// centenas de registros, e tê-las em memória deixa a busca da tela de
  /// catálogo instantânea — filtrar no aparelho evita uma ida ao servidor
  /// por tecla digitada. Também significa que tocar num item abre a ficha
  /// sem nova consulta, porque o modelo completo já está carregado.
  Future<List<SnakeModel>> listAllSnakes() async {

    // `ascending: true` é obrigatório: o padrão do cliente Dart é
    // DESCENDENTE, então `.order('specie')` sozinho devolvia a lista de Z a A.
    final response = await supabase
        .from('snakes')
        .select()
        .order('specie', ascending: true);

    return (response as List)
        .map((row) => SnakeModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Busca pelo nome científico, do jeito que o modelo devolve
  /// ('Corallus hortulana')
  /// É por aqui que a tela de câmera resolve a espécie identificada. O
  /// `snake_id` do servidor de inferência cobre só as espécies mapeadas à
  /// mão no `SPECIE_TO_ID` de `lib/models/main.py`, enquanto o nome vem
  /// para todas as 246 que o modelo reconhece — então basta a espécie
  /// existir na tabela `snakes` para a ficha aparecer.
  /// Segue a mesma convenção de erro do getSnakeById: `maybeSingle`
  /// devolve null quando a espécie não está cadastrada, e qualquer outra
  /// falha (rede, servidor, timeout) sobe como exceção para a CameraPage
  /// mostrar a mensagem específica em vez de "espécie não encontrada".
  Future<SnakeModel?> getSnakeBySpecie(String specie) async {

    final response = await supabase
        .from('snakes')
        .select()
        .eq('specie', specie)
        .maybeSingle();

    if (response == null) return null;

    return SnakeModel.fromMap(response);
  }
}