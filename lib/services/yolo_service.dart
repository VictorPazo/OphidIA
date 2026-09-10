import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

// 🐍 RESULTADO DA DETECÇÃO
// Guarda tudo que a tela de câmera precisa: se achou, o quadrado em
// pixels (espaço da imagem original) e as dimensões da imagem — o
// backend já devolve nesse formato pra evitar redecodificar o arquivo
// no app só pra saber o tamanho.
class DetectionResult {

  final bool found;

  final double? confidence;

  final double? x1;
  final double? y1;
  final double? x2;
  final double? y2;

  final int imageWidth;
  final int imageHeight;

  DetectionResult({
    required this.found,
    required this.imageWidth,
    required this.imageHeight,
    this.confidence,
    this.x1,
    this.y1,
    this.x2,
    this.y2,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {

    final bbox = json['bbox'] as Map<String, dynamic>?;

    return DetectionResult(
      found: json['found'] as bool,
      imageWidth: json['image_width'] as int,
      imageHeight: json['image_height'] as int,
      confidence: (json['confidence'] as num?)?.toDouble(),
      x1: (bbox?['x1'] as num?)?.toDouble(),
      y1: (bbox?['y1'] as num?)?.toDouble(),
      x2: (bbox?['x2'] as num?)?.toDouble(),
      y2: (bbox?['y2'] as num?)?.toDouble(),
    );
  }
}

class YoloService {

  // ⚠️ Troque pelo mesmo baseUrl usado em agent_service.dart — o ideal
  // é os dois lerem de uma única constante compartilhada, em vez de
  // duplicar o endereço do servidor em dois arquivos.
  static const String baseUrl = 'http://IP:8000';

  Future<DetectionResult?> detectSnake(File imageFile) async {

    try {

      final uri = Uri.parse('$baseUrl/detect');

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      return DetectionResult.fromJson(json);

    } catch (e) {

      // 🔌 SEM REDE / SERVIDOR FORA
      // Retorna null — a tela de câmera trata isso deixando o usuário
      // seguir para o fluxo normal, em vez de travar a identificação
      // só porque o YOLO não respondeu.
      return null;
    }
  }
}