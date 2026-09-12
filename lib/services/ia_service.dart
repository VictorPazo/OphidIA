import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exceptions.dart';

class IAService {

  // Endereço do servidor em api_config.dart — o mesmo que o YoloService
  // usa. Troque lá, num lugar só.
  final String baseUrl = ApiConfig.baseUrl;

  // ⏱️ TEMPO LIMITE
  //
  // Era de 5 minutos, herdado de quando o servidor rodava na máquina local em
  // CPU. Ninguém encara uma tela de carregamento por cinco minutos: na prática
  // o usuário conclui que travou e fecha o app, e o erro nunca chega a
  // aparecer.
  //
  // 45 segundos é folgado para o caso real. A primeira identificação do dia,
  // com o Lambda frio carregando os dois modelos, mediu 7 segundos; as
  // seguintes, 3. A margem cobre 5G instável em campo.
  static const Duration _timeout = Duration(seconds: 45);

  // Tipos de falha sinalizados :
  // - SocketException: sem conexão com o servidor (rede caiu, IP errado)
  // - TimeoutException: servidor não respondeu a tempo (sobrecarga, rede lenta)
  // - ServerException: servidor respondeu, mas com erro — INTERNAL SERVER ERROR
  // - ClientException: servidor respondeu - BAD REQUEST
  Future<Map<String, dynamic>> predictSnake(File imageFile) async {

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/predict'),
    );

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final response = await request
        .send()
        .timeout(_timeout);

    // O limite cobre a leitura também: a resposta pode começar a chegar e
    // travar no meio se a conexão cair, e sem isto a espera seria infinita.
    final responseBody =
        await response.stream.bytesToString().timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    }

    if (response.statusCode >= 500) {
      throw ServerException(
        'IA respondeu com erro ${response.statusCode}: $responseBody',
      );
    }

    throw ClientException(
      'Requisição rejeitada (${response.statusCode}): $responseBody',
    );
  }
}