import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/upload_result.dart';

class UploadService {

  final supabase = Supabase.instance.client;

  Future<UploadResult> uploadImage(File file) async {

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = 'uploads/$fileName';

    await supabase.storage
        .from('user-history')
        .upload(filePath, file);

    final publicUrl = supabase.storage
        .from('user-history')
        .getPublicUrl(filePath);

    return UploadResult(
      filePath: filePath,
      signedUrl: publicUrl,
    );
  }
}