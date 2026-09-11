import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/snake_model.dart';
import '../services/snake_info.dart';
import '../theme/app_theme.dart';
import '../theme/animated_entrance.dart';
import '../screens/screens.dart';
import '../utils/dentition_helper.dart';

class SnakeInformationScreen
    extends StatefulWidget {

  final SnakeModel snake;
  final double confidence;
  final String imageUrl;
  final String? heroTag;
  final double? latitude;
  final double? longitude;

  /// Ranking completo devolvido pelo `/predict`, da espécie mais provável
  /// para a menos — cada item com `specie`, `confidence` e `snake_id`.
  ///
  /// O modelo acerta 76,8% na primeira posição, mas 90,0% considerando as
  /// três primeiras. Exibir as alternativas devolve ao usuário esses 13
  /// pontos que, mostrando só o topo, seriam simplesmente perdidos.
  ///
  /// Vem vazio nas telas abertas pelo histórico, onde não há predição.
  final List<Map<String, dynamic>> ranking;

  const SnakeInformationScreen({
    super.key,
    required this.snake,
    required this.confidence,
    required this.imageUrl,
    this.heroTag,
    this.latitude,
    this.longitude,
    this.ranking = const [],
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
                    taxonomyRow(
                      "family".tr(),
                      widget.snake.family,
                      "genus".tr(),
                      widget.snake.genus,
                    ),
                    dentitionRow(
                      "poisonous".tr(),
                      widget.snake.poisonous ? "yes".tr() : "no".tr(),
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

            // Vem depois da ficha completa: a espécie identificada é a
            // resposta, e as alternativas são a ressalva — inverter a ordem
            // faria o usuário duvidar antes mesmo de ler o resultado.
            FadeSlideIn(
              delay: const Duration(milliseconds: 240),
              child: buildAlternatives(),
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

  // 🥈 OUTRAS POSSIBILIDADES
  //
  // Mostra as posições 2 e 3 do ranking. São tocáveis quando a espécie já
  // existe na tabela `snakes`: quem reconhece o animal na segunda opção
  // consegue abrir a ficha dela, em vez de ficar preso na primeira.
  //
  // Some inteiro no histórico (ranking vazio) e quando o usuário desliga a
  // confiança nas Configurações — são o mesmo dado, e seria incoerente
  // esconder a porcentagem principal e manter as alternativas.
  Widget buildAlternatives() {

    final alternativas = widget.ranking.skip(1).toList();

    if (alternativas.isEmpty || !showConfidence) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fieldLabel("other_possibilities".tr()),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "other_possibilities_hint".tr(),
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final alt in alternativas) alternativeTile(alt),
          ],
        ),
      ),
    );
  }

  Widget alternativeTile(Map<String, dynamic> alt) {

    final specie = (alt["specie"] ?? "").toString();
    final conf = (alt["confidence"] as num?)?.toDouble() ?? 0;
    final temFicha = alt["snake_id"] != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: temFicha ? () => openAlternative(specie) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        specie,
                        style: const TextStyle(
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Barra proporcional à confiança: dá a noção de
                      // distância entre as opções num relance, que só o
                      // número não passa.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (conf / 100).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: const Color(0xFFE8EDE9),
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.accent,
                          ),
                        ),
                      ),
                      if (!temFicha) ...[
                        const SizedBox(height: 6),
                        Text(
                          "species_not_registered".tr(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  "${conf.toStringAsFixed(1)}%",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: temFicha ? Colors.black38 : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openAlternative(String specie) async {

    final servico = SnakeInformationService();
    final outra = await servico.getSnakeBySpecie(specie);

    if (!mounted) return;

    if (outra == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("fetch_snake_error".tr())),
      );
      return;
    }

    final conf = widget.ranking.firstWhere(
      (r) => r["specie"] == specie,
      orElse: () => const {"confidence": 0},
    )["confidence"];

    // push (e não pushReplacement): o usuário está explorando alternativas
    // e deve conseguir voltar para a identificação principal.
    Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => SnakeInformationScreen(
          snake: outra,
          confidence: (conf as num).toDouble(),
          imageUrl: widget.imageUrl,
          latitude: widget.latitude,
          longitude: widget.longitude,
          ranking: widget.ranking,
        ),
        transition: AppTransition.slide,
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

  // 🏷️ RÓTULO ACIMA, VALOR ABAIXO
  // Padrão único de toda a ficha. Além da consistência, resolve um problema
  // real do formato "Rótulo: valor": rótulos longos como "Tipo de veneno"
  // comiam metade da largura e empurravam o valor para quebrar em duas linhas
  // desalinhadas. Com o rótulo acima, o valor sempre tem a largura inteira.
  Widget infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fieldLabel(title),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  // Estilo único dos rótulos da ficha.
  Widget fieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: Colors.black54,
      ),
    );
  }

  // 🧬 FAMÍLIA + GÊNERO
  // Dois dados curtos e da mesma natureza (posição taxonômica) ocupando duas
  // linhas inteiras desperdiça altura numa tela que já é longa. Lado a lado,
  // com o rótulo acima em caixa alta e menor, o valor ganha mais destaque do
  // que no padrão "Rótulo: valor" e as duas colunas cabem sem aperto.
  Widget taxonomyRow(
      String familyLabel,
      String family,
      String genusLabel,
      String genus,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: taxonomyCell(familyLabel, family, italic: false),
            ),
            const SizedBox(width: AppSpacing.md),

            // O divisor separa duas palavras curtas que, lado a lado e sem
            // nada entre elas, seriam lidas como uma frase só.
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: Color(0xFFE4E8E4),
            ),
            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: taxonomyCell(genusLabel, genus, italic: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget taxonomyCell(
      String label,
      String value, {
        required bool italic,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        fieldLabel(label),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,

            // Nome de gênero é nome científico e vai em itálico, como manda a
            // convenção taxonômica. Nome de família, não.
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }

  // ☠️ VENENOSA + 🦷 TIPO DE DENTIÇÃO
  // Andam juntos por serem a mesma informação vista de dois ângulos: o tipo
  // de dentição é justamente o que define como (e se) a serpente inocula
  // peçonha. Lado a lado, a relação entre os dois fica evidente.
  //
  // O desenho continua abaixo e em largura total, e não dentro da coluna da
  // dentição: espremido em meia largura ele voltaria a ficar pequeno demais
  // para mostrar a posição das presas, que é todo o propósito dele.
  Widget dentitionRow(
      String poisonousLabel,
      String poisonous,
      String title,
      String value,
      ) {

    final imageAsset = dentitionImageAsset(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: taxonomyCell(
                    poisonousLabel,
                    poisonous,
                    italic: false,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFE4E8E4),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: taxonomyCell(title, value, italic: false),
                ),
              ],
            ),
          ),

          // 🦷 O DESENHO É CONTEÚDO, NÃO ÍCONE
          // A 48px não dava para distinguir a posição das presas, que é
          // justamente o que a imagem explica. Abaixo do texto e em largura
          // total ele fica legível, e sai do caminho da linha de texto — era
          // a disputa por espaço na mesma Row que estourava o layout.
          if (imageAsset != null) ...[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () => openDentitionViewer(imageAsset, value),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F5F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Hero(
                      tag: 'dentition_$imageAsset',
                      child: Image.asset(
                        imageAsset,
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.contain,

                        // Um asset ausente vira um widget de erro com tamanho
                        // próprio, que já estourou esta tela uma vez. Aqui a
                        // falha custa só o desenho: o texto continua legível.
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),

                    // 🔍 AFORDÂNCIA
                    // Sem um sinal visível, ninguém descobre que a imagem
                    // abre — toque em imagem não é gesto óbvio numa ficha
                    // de leitura.
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.zoom_in,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🔍 VISUALIZADOR AMPLIADO
  // A miniatura de 150px basta para reconhecer o tipo de dentição, mas não
  // para examinar a posição e o formato das presas — que é o detalhe que
  // distingue uma solenóglifa de uma proteróglifa. Aqui a imagem abre em tela
  // cheia, com pinça para aproximar e arrastar para navegar.
  void openDentitionViewer(String imageAsset, String dentitionName) {

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,

        // Sem transição própria: quem anima é o Hero da imagem, saindo da
        // miniatura e crescendo até a tela cheia.
        transitionDuration: const Duration(milliseconds: 250),

        pageBuilder: (context, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Colors.transparent,

            body: SafeArea(
              child: Stack(
                children: [

                  // Toque em qualquer lugar fora da imagem fecha — é o gesto
                  // que as pessoas tentam primeiro.
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),

                  Center(
                    child: Hero(
                      tag: 'dentition_$imageAsset',
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: Image.asset(
                          imageAsset,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            dentitionName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          color: Colors.white,
                          tooltip: "close".tr(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}