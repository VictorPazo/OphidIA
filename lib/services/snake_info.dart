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
}