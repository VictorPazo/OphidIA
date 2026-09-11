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
        .timeout(const Duration(minutes: 5));

    final responseBody = await response.stream.bytesToString();

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