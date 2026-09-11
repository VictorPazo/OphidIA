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

  /// Busca pelo nome científico, do jeito que o modelo devolve
  /// ('Corallus hortulana').
  ///
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