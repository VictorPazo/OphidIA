import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/snake_model.dart';
import '../theme/app_theme.dart';
import '../theme/animated_entrance.dart';
import '../screens/screens.dart'; // HomePage, HistoryPage

class SnakeInformationScreen
    extends StatefulWidget {

  final SnakeModel snake;
  final double confidence;
  final String imageUrl;
  final String? heroTag;
  final double? latitude;
  final double? longitude;

  const SnakeInformationScreen({
    super.key,
    required this.snake,
    required this.confidence,
    required this.imageUrl,
    this.heroTag,
    this.latitude,
    this.longitude,
  });

  @override
  State<SnakeInformationScreen> createState() =>
      _SnakeInformationScreenState();
}

class _SnakeInformationScreenState
    extends State<SnakeInformationScreen> {

  bool showConfidence = true;
  bool isSaving = false;
  bool get isNewIdentification => widget.heroTag != null;

  @override
  void initState() {
    super.initState();
    loadShowConfidenceSetting();
  }

  Future<void> loadShowConfidenceSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool('showConfidence') ?? true;
    if (!mounted) return;
    setState(() {
      showConfidence = value;
    });
  }

  Future<void> saveToHistory() async {

    setState(() {
      isSaving = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      await Supabase.instance.client
          .from('snake_historic')
          .insert({
        'profiles_id': user!.id,
        'snakes_id': widget.snake.id,
        'image_url': widget.imageUrl,
        'data_photo': DateTime.now().toIso8601String(),
        'latitude': widget.latitude,
        'longitude': widget.longitude,
      });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        AppPageRoute(
          builder: (_) => const HistoryPage(),
          transition: AppTransition.fade,
        ),
            (route) => false,
      );

    } catch (e, stackTrace) {

      debugPrint('Erro ao salvar histórico: $e');
      debugPrint(stackTrace.toString());

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("save_history_error".tr())),
      );
    }
  }

  void discardAndGoHome() {

    Navigator.pushAndRemoveUntil(
      context,
      AppPageRoute(
        builder: (_) => const HomePage(),
        transition: AppTransition.fade,
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

    final image = Supabase.instance.client.storage
        .from('snake-species')
        .getPublicUrl(widget.snake.imageName);

    final bool hasConfidence = widget.confidence > 0;

    Widget snakeImage = Image.network(
      image,
      height: 250,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 250,
          width: double.infinity,
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.image_not_supported, size: 50),
          ),
        );
      },
    );

    if (widget.heroTag != null) {
      snakeImage = Hero(tag: widget.heroTag!, child: snakeImage);
    }

    return Scaffold(

      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("snake_identified".tr()),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [

            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: snakeImage,
            ),

            const SizedBox(height: AppSpacing.lg),

            FadeSlideIn(
              child: Text(
                widget.snake.specie,
                textAlign: TextAlign.center,
                style: AppTextStyles.screenTitle,
              ),
            ),

            if (showConfidence && hasConfidence) ...[
              const SizedBox(height: AppSpacing.md),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: buildConfidenceBadge(),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            FadeSlideIn(
              delay: const Duration(milliseconds: 140),
              child: buildMedicalDisclaimer(),
            ),

            const SizedBox(height: AppSpacing.lg),

            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoRow("family".tr(), widget.snake.family),
                    infoRow("genus".tr(), widget.snake.genus),
                    infoRow(
                      "poisonous".tr(),
                      widget.snake.poisonous ? "yes".tr() : "no".tr(),
                    ),
                    infoRow(
                      "dentition_type".tr(),
                      widget.snake.dentition_type.toString(),
                    ),
                    infoRow("venom_type".tr(), widget.snake.venomType),
                    infoRow(
                      "antivenom".tr(),
                      widget.snake.effectiveAntivenom ?? "not_informed".tr(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      "description".tr(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.snake.description ?? "no_description".tr(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            if (isNewIdentification) ...[

              const SizedBox(height: AppSpacing.lg),

              FadeSlideIn(
                delay: const Duration(milliseconds: 260),
                child: Column(
                  children: [

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : saveToHistory,
                        child: isSaving
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Text("save_to_history".tr()),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.onBackground,
                        ),
                        onPressed: isSaving ? null : discardAndGoHome,
                        child: Text("do_not_save".tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildConfidenceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.psychology_outlined,
            color: AppColors.onBackground,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            "${"ai_confidence".tr()}: "
                "${widget.confidence.toStringAsFixed(1)}%",
            style: const TextStyle(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMedicalDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "medical_disclaimer_title".tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "medical_disclaimer_text".tr(),
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}