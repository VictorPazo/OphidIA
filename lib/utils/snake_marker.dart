import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Desenha o marcador do mapa: a foto da espécie dentro de um alfinete
/// circular, com a borda colorida pelo risco.
///
/// O pino vermelho padrão não dizia nada. Numa tela com vários registros, uma
/// jararaca e uma caninana ficavam idênticas — e distinguir as duas é
/// justamente o propósito do app. Aqui a cor da borda separa peçonhenta de não
/// peçonhenta antes de qualquer toque, e a foto deixa a espécie reconhecível
/// sem abrir nada.
class SnakeMarker {

  const SnakeMarker._();

  /// Vermelho e verde carregam o significado, mas nunca sozinhos: a janela de
  /// informação sempre repete "Peçonhenta" ou "Não peçonhenta" por escrito,
  /// porque cerca de 8% dos homens têm alguma deficiência na visão de cores.
  static const Color _perigo = Color(0xFFC62828);
  static const Color _seguro = Color(0xFF2E7D32);

  /// Um marcador por espécie é reaproveitado entre todos os registros dela.
  /// Sem isso, vinte avistamentos de jararaca baixariam a mesma foto vinte
  /// vezes.
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Evita que dois marcadores da mesma espécie disparem downloads paralelos
  /// enquanto o primeiro ainda está em andamento.
  static final Map<String, Future<BitmapDescriptor>> _emCurso = {};

  static Future<BitmapDescriptor> build({
    required String cacheKey,
    required String? imageUrl,
    required bool poisonous,
  }) {
    final chave = '$cacheKey|$poisonous';

    final pronto = _cache[chave];
    if (pronto != null) return Future.value(pronto);

    return _emCurso[chave] ??= _desenhar(imageUrl, poisonous).then((bmp) {
      _cache[chave] = bmp;
      _emCurso.remove(chave);
      return bmp;
    }).catchError((_) {
      _emCurso.remove(chave);
      // Falha de rede não pode deixar o avistamento sumir do mapa: cai no
      // pino padrão, com a cor certa.
      return BitmapDescriptor.defaultMarkerWithHue(
        poisonous ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen,
      );
    });
  }

  static Future<BitmapDescriptor> _desenhar(
    String? imageUrl,
    bool poisonous,
  ) async {

    const double lado = 80;        // largura do alfinete em pixels
    const double raio = 32;        // raio do círculo da foto
    const double borda = 4;
    const double ponta = 14;       // bico que aponta para a coordenada

    final cor = poisonous ? _perigo : _seguro;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final centro = const Offset(lado / 2, raio + borda);

    // Bico do alfinete, desenhado antes do círculo para ficar atrás dele.
    final bico = Path()
      ..moveTo(centro.dx - 15, centro.dy + raio - 6)
      ..lineTo(centro.dx, centro.dy + raio + ponta)
      ..lineTo(centro.dx + 15, centro.dy + raio - 6)
      ..close();

    canvas.drawPath(bico, Paint()..color = cor);

    canvas.drawCircle(centro, raio + borda / 2, Paint()..color = cor);
    canvas.drawCircle(centro, raio, Paint()..color = Colors.white);

    ui.Image? foto;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      foto = await _baixar(imageUrl);
    }

    if (foto != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(
        Rect.fromCircle(center: centro, radius: raio - 3),
      ));

      // Recorta o quadrado central da foto antes de encaixar no círculo, em
      // vez de espremer a imagem inteira: esticar deformaria o padrão do
      // corpo, que é o que torna a espécie reconhecível.
      final menor = math.min(foto.width, foto.height).toDouble();
      final origem = Rect.fromLTWH(
        (foto.width - menor) / 2,
        (foto.height - menor) / 2,
        menor,
        menor,
      );
      final destino = Rect.fromCircle(center: centro, radius: raio - 3);

      canvas.drawImageRect(foto, origem, destino, Paint());
      canvas.restore();
    } else {
      // Sem foto cadastrada, uma cobra enrodilhada com a cor do risco.
      _desenharCobra(canvas, centro, raio, cor);
    }

    final img = await recorder
        .endRecording()
        .toImage(lado.toInt(), (raio + borda) * 2 ~/ 1 + ponta.toInt());

    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// Cobra enrodilhada, vista de cima: uma espiral que se abre, com a cabeça
  /// na ponta externa e a língua bifurcada.
  ///
  /// Desenhada em vez de usar um ícone pronto porque o Material não tem
  /// nenhum que sirva — o mais próximo é uma pegada de pata, que confunde em
  /// vez de informar. A espiral escala sem perder nitidez em qualquer tamanho
  /// de marcador.
  static void _desenharCobra(
    Canvas canvas,
    Offset centro,
    double raio,
    Color cor,
  ) {
    const voltas = 2.15;
    const passos = 120;

    final corpo = Path();
    late Offset cabeca;
    late double anguloFinal;

    for (int i = 0; i <= passos; i++) {
      final t = i / passos;
      final ang = t * voltas * 2 * math.pi;
      final r = raio * (0.12 + 0.52 * t);
      final p = Offset(
        centro.dx + r * math.cos(ang),
        centro.dy + r * math.sin(ang),
      );
      if (i == 0) {
        corpo.moveTo(p.dx, p.dy);
      } else {
        corpo.lineTo(p.dx, p.dy);
      }
      cabeca = p;
      anguloFinal = ang;
    }

    // O corpo afina da cauda para o centro, mas um traço de espessura única
    // lê melhor em 64 pixels do que um degradê de largura.
    canvas.drawPath(
      corpo,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = raio * 0.17
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(cabeca, raio * 0.135, Paint()..color = cor);

    // Língua: duas hastes curtas saindo da cabeça, na direção em que ela
    // aponta.
    final dir = Offset(math.cos(anguloFinal + math.pi / 2),
                       math.sin(anguloFinal + math.pi / 2));
    final base = cabeca + dir * (raio * 0.13);
    final lingua = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = raio * 0.055
      ..strokeCap = StrokeCap.round;

    for (final desvio in const [-0.38, 0.38]) {
      final d = Offset(
        math.cos(anguloFinal + math.pi / 2 + desvio),
        math.sin(anguloFinal + math.pi / 2 + desvio),
      );
      canvas.drawLine(base, base + d * (raio * 0.20), lingua);
    }
  }

  static Future<ui.Image?> _baixar(String url) async {
    try {
      final r = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (r.statusCode != 200) return null;

      final codec = await ui.instantiateImageCodec(
        r.bodyBytes,
        targetWidth: 160,   // o marcador é pequeno; baixar em tamanho cheio
                            // gastaria memória à toa
      );
      return (await codec.getNextFrame()).image;

    } catch (_) {
      return null;
    }
  }
}
