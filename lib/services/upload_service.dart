import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/upload_result.dart';

class UploadService {

  final supabase = Supabase.instance.client;

  Future<UploadResult> uploadImage(File file) async {

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = 'uploads/$fileName';

    // ⏱️ O upload roda ANTES da identificação e a bloqueia: se ele pendurar,
    // o usuário fica na tela de carregamento sem nunca ver a espécie, mesmo
    // com o servidor de IA respondendo normalmente. O cliente do Supabase não
    // traz limite próprio.
    //
    // 60 segundos é mais folgado que os 45 da identificação porque aqui sobe
    // a foto inteira, e não uma resposta em texto.
    await supabase.storage
        .from('user-history')
        .upload(filePath, file)
        .timeout(const Duration(seconds: 60));

    final publicUrl = supabase.storage
        .from('user-history')
        .getPublicUrl(filePath);

    return UploadResult(
      filePath: filePath,
      signedUrl: publicUrl,
    );
  }
}