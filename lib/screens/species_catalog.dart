import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/snake_model.dart';
import '../services/snake_info.dart';
import '../theme/app_page_route.dart';
import '../theme/app_theme.dart';
import '../theme/image_viewer.dart';
import '../theme/info_hint.dart';
import '../theme/skeleton.dart';
import '../utils/snake_marker.dart';
import '../utils/snake_risk.dart';
import '../utils/specie_match.dart';
import 'snake_information.dart';

/// Catálogo das espécies cadastradas, com busca.
///
/// Existe porque o acervo já estava construído e inalcançável: as fichas do
/// banco só apareciam para quem tivesse a sorte de fotografar aquela espécie.
/// O texto de consentimento chama o app de ferramenta educativa, e sem um
/// encontro não havia nada a consultar.
///
/// Deliberadamente simples: lista e busca. Sem filtro por gênero, sem
/// navegação taxonômica, sem comparação entre espécies — isso transformaria
/// um atalho para dados existentes em um produto à parte.
///
/// Mostra apenas as espécies que o modelo reconhece, não tudo o que está na
/// tabela. As duas listas nasceram de critérios diferentes: o banco veio do
/// GBIF por gênero (toda espécie daquele gênero com ocorrência no Brasil),
/// enquanto o modelo cobre as que tinham fotos suficientes para treinar.
/// Exibir uma espécie que o app não identifica prometeria o que ele não faz.
class SpeciesCatalogPage extends StatefulWidget {

  const SpeciesCatalogPage({super.key});

  @override
  State<SpeciesCatalogPage> createState() => _SpeciesCatalogPageState();
}

class _SpeciesCatalogPageState extends State<SpeciesCatalogPage> {

  final SnakeInformationService service = SnakeInformationService();

  final TextEditingController buscaController = TextEditingController();

  /// Espécies do banco que o modelo reconhece — já filtradas.
  List<SnakeModel> todas = [];

  /// Quantas espécies o modelo reconhece no total, inclusive as que ainda
  /// não têm ficha no banco. A diferença entre este número e
  /// `todas.length` é o tamanho do vão de cadastro, e aparece no topo da
  /// tela em vez de ficar escondida.
  int totalDoModelo = 0;

  bool carregando = true;
  bool falhou = false;

  /// Texto da busca, normalizado uma vez por digitação em vez de a cada
  /// espécie comparada.
  String termo = '';

  @override
  void initState() {
    super.initState();
    carregarEspecies();
  }

  @override
  void dispose() {
    buscaController.dispose();
    super.dispose();
  }

  Future<void> carregarEspecies() async {

    setState(() {
      carregando = true;
      falhou = false;
    });

    try {

      // As duas fontes em paralelo: o asset é local e resolve de imediato,
      // então não faz sentido esperar por ele antes de pedir a rede.
      final resultados = await Future.wait([
        carregarEspeciesDoModelo(),
        service.listAllSnakes(),
      ]);

      final reconhecidas = resultados[0] as Set<String>;
      final doBanco = resultados[1] as List<SnakeModel>;

      final lista = doBanco
          .where((snake) => reconhecidas.contains(specieKey(snake.specie)))
          .toList();

      if (!mounted) return;

      setState(() {
        todas = lista;
        totalDoModelo = reconhecidas.length;
        carregando = false;
      });

    } catch (e) {

      if (!mounted) return;

      setState(() {
        carregando = false;
        falhou = true;
      });
    }
  }

  /// Nomes das espécies que o modelo reconhece, prontos para comparação.
  ///
  /// Lê `lib/models/classes.json`, o mesmo arquivo que o servidor de
  /// inferência carrega. Vale o aviso que já está no CLAUDE.md: esse arquivo
  /// e o `best_model.pth` publicado têm que ser do mesmo treino, senão as
  /// predições trocam de espécie silenciosamente — e agora o catálogo passa
  /// a depender do mesmo par.
  Future<Set<String>> carregarEspeciesDoModelo() async {

    final bruto = await rootBundle.loadString('lib/models/classes.json');

    final List<dynamic> classes = jsonDecode(bruto) as List<dynamic>;

    return classes.map((c) => specieKey(c.toString())).toSet();
  }

  /// Busca por nome científico, gênero, família ou nome popular.
  ///
  /// O campo anuncia apenas nome científico e gênero porque hoje é só isso
  /// que existe: a coluna de nome popular está praticamente vazia, e
  /// prometer uma busca que não devolve nada é pior do que não prometer.
  ///
  /// A comparação por nome popular fica no código de propósito — ela passa a
  /// funcionar sozinha conforme o cadastro for preenchido, e aí basta
  /// atualizar o texto do campo.
  List<SnakeModel> get filtradas {

    if (termo.isEmpty) return todas;

    final locale = context.locale.languageCode;

    return todas.where((snake) {

      final popular = snake.localizedPopularName(locale) ?? '';

      return normalizeDentition(snake.specie).contains(termo) ||
          normalizeDentition(popular).contains(termo) ||
          normalizeDentition(snake.genus).contains(termo) ||
          normalizeDentition(snake.family).contains(termo);

    }).toList();
  }

  void abrirFicha(SnakeModel snake) {

    Navigator.push(
      context,
      AppPageRoute(
        // Sem heroTag de propósito: é o que faz a ficha entender que não há
        // identificação em curso, escondendo os botões de salvar no
        // histórico e o pedido de consentimento. Consulta não é avistamento.
        builder: (_) => SnakeInformationScreen(
          snake: snake,
          confidence: 0,
          imageUrl: '',
        ),
        transition: AppTransition.slide,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.background,

      body: SafeArea(

        child: Column(

          children: [

            buildHeader(),

            buildSearchField(),

            const SizedBox(height: AppSpacing.sm),

            Expanded(child: buildBody()),
          ],
        ),
      ),
    );
  }

  Widget buildHeader() {

    return Padding(

      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),

      child: Row(

        children: [

          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.onBackground,
            ),
            onPressed: () => Navigator.pop(context),
          ),

          Expanded(
            child: Text(
              "catalog_title".tr(),
              style: AppTextStyles.screenTitle,
            ),
          ),

          // A contagem não é enfeite: mostra de saída quantas espécies o app
          // identifica e quantas delas já têm ficha. É a única parte da
          // interface onde o alcance real do projeto fica visível, e o "i"
          // ao lado explica a diferença entre os dois números em vez de
          // deixar o usuário supondo.
          if (!carregando && !falhou) ...[
            Text(
              '${todas.length}/$totalDoModelo',
              style: const TextStyle(
                color: AppColors.onBackgroundMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            InfoHint(
              title: "catalog_count_info_title".tr(),
              body: "catalog_count_info_body".tr(
                namedArgs: {
                  'comFicha': '${todas.length}',
                  'total': '$totalDoModelo',
                },
              ),
              color: AppColors.onBackgroundMuted,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget buildSearchField() {

    return Padding(

      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
      ),

      child: TextField(

        controller: buscaController,

        style: const TextStyle(color: AppColors.onSurface),

        textInputAction: TextInputAction.search,

        decoration: InputDecoration(

          hintText: "catalog_search_hint".tr(),

          filled: true,
          fillColor: AppColors.surface,

          prefixIcon: const Icon(Icons.search),

          suffixIcon: termo.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    buscaController.clear();
                    setState(() => termo = '');
                  },
                ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),

          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: AppSpacing.md,
          ),
        ),

        onChanged: (valor) {
          setState(() => termo = normalizeDentition(valor));
        },
      ),
    );
  }

  Widget buildBody() {

    if (carregando) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: SkeletonBox(
            height: 76,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      );
    }

    if (falhou) {
      return buildEmptyState(
        icon: Icons.cloud_off,
        message: "catalog_load_error".tr(),
        action: TextButton(
          onPressed: carregarEspecies,
          child: Text(
            "catalog_retry".tr(),
            style: const TextStyle(color: AppColors.onBackground),
          ),
        ),
      );
    }

    final lista = filtradas;

    if (lista.isEmpty) {
      return buildEmptyState(
        icon: Icons.search_off_rounded,
        message: "catalog_no_results".tr(),
      );
    }

    // ListView.builder constrói só o visível: as fotos das espécies fora da
    // tela não são baixadas, então a lista inteira não pesa na rede.
    return ListView.builder(

      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),

      itemCount: lista.length,

      itemBuilder: (context, index) => buildSpeciesCard(lista[index]),
    );
  }

  Widget buildEmptyState({
    required IconData icon,
    required String message,
    Widget? action,
  }) {

    return Center(

      child: Padding(

        padding: const EdgeInsets.all(AppSpacing.xl),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(
              icon,
              color: AppColors.onBackgroundMuted,
              size: 44,
            ),

            const SizedBox(height: AppSpacing.md),

            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.onBackgroundMuted,
                fontSize: 14,
                height: 1.35,
              ),
            ),

            if (action != null) ...[
              const SizedBox(height: AppSpacing.sm),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget buildSpeciesCard(SnakeModel snake) {

    final locale = context.locale.languageCode;

    // O cartão tem `maxLines: 1`, então exibe só o primeiro nome. A busca,
    // logo acima, varre o campo inteiro com as variantes regionais.
    final popular = snake.localizedPopularNameMain(locale);

    final risk = riskFromDentition(snake.dentition_type.toString());

    final foto = snake.imageName.isEmpty
        ? null
        : Supabase.instance.client.storage
            .from('snake-species')
            .getPublicUrl(snake.imageName);

    return Padding(

      padding: const EdgeInsets.only(bottom: AppSpacing.sm),

      child: Material(

        color: AppColors.accent,

        borderRadius: BorderRadius.circular(16),

        child: InkWell(

          borderRadius: BorderRadius.circular(16),

          onTap: () => abrirFicha(snake),

          child: Padding(

            padding: const EdgeInsets.all(AppSpacing.sm),

            child: Row(

              children: [

                buildThumbnail(foto, snake),

                const SizedBox(width: AppSpacing.md),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,

                    children: [

                      // Nome popular em primeiro lugar quando existe, porque
                      // é por ele que a pessoa reconhece o animal. Sem ele, o
                      // nome científico sobe para o lugar de destaque em vez
                      // de deixar o cartão sem título.
                      Text(
                        popular ?? snake.specie,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.onBackground,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              popular == null ? FontStyle.italic : null,
                        ),
                      ),

                      if (popular != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          snake.specie,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onBackgroundMuted,
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.sm),

                if (risk != null) buildRiskDot(risk),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildThumbnail(String? url, SnakeModel snake) {

    const double lado = 60;

    final miniatura = ClipRRect(

      borderRadius: BorderRadius.circular(12),

      child: SizedBox(

        width: lado,
        height: lado,

        child: url == null
            ? buildThumbnailFallback()
            : Image.network(
                url,
                fit: BoxFit.cover,

                // 🧠 DECODIFICAR PEQUENO É O QUE MANTÉM A LISTA ESTÁVEL
                //
                // Sem isto a foto é decodificada em resolução cheia para caber
                // num quadrado de 60 px. O cache de imagens do Flutter limita
                // 100 MiB DESCOMPACTADOS, e uma foto grande passa de 10 MB —
                // couberam umas oito, ou seja uma tela. Rolar estourava o
                // limite, o descarte removia as de cima, e voltar baixava tudo
                // outra vez, num ciclo sem fim.
                //
                // Decodificando a 200 px as 224 fichas somam uns 27 MB e
                // convivem no cache. É a mesma medida que `snake_marker.dart`
                // já tomava para os pinos do mapa.
                //
                // Só a largura é fixada: definir os dois eixos faria a
                // decodificação ignorar a proporção e achatar a foto.
                cacheWidth: 200,

                // Aparição suave: a lista mostra o espaço reservado e a foto
                // entra por cima, em vez de a linha dar um salto quando ela
                // chega.
                frameBuilder: (_, child, frame, carregadaSincrona) {
                  if (carregadaSincrona || frame != null) return child;
                  return buildThumbnailFallback();
                },

                // Espécie sem foto cadastrada não pode deixar um buraco no
                // cartão: cai no mesmo marcador neutro.
                errorBuilder: (_, _, _) => buildThumbnailFallback(),
              ),
      ),
    );

    if (url == null) return miniatura;

    // 🔍 MINIATURA AMPLIÁVEL
    // Tocar na foto amplia; tocar no resto do cartão abre a ficha. Em 60 px
    // não dá para ver o desenho do corpo, que é o que se compara com o animal
    // encontrado — e abrir a ficha inteira só para isso seria um passo a
    // mais. O visualizador carrega a foto em resolução cheia, e não a
    // miniatura de 200 px que a lista usa.
    final heroTag = 'catalog_photo_${snake.id}';

    return GestureDetector(
      onTap: () => openImageViewer(
        context,
        image: NetworkImage(url),
        title: snake.specie,
        italicTitle: true,
        heroTag: heroTag,
      ),
      child: Stack(
        children: [
          Hero(tag: heroTag, child: miniatura),
          const Positioned(
            right: 2,
            bottom: 2,
            child: ZoomBadge(size: 12),
          ),
        ],
      ),
    );
  }

  Widget buildThumbnailFallback() {

    return Container(

      color: Colors.white.withValues(alpha: 0.08),

      child: const Icon(
        Icons.pets,
        color: AppColors.onBackgroundMuted,
        size: 22,
      ),
    );
  }

  /// Mesma cor que o marcador do mapa usa, lida da mesma função — a
  /// classificação não pode divergir entre uma tela e outra.
  ///
  /// A cor nunca informa sozinha: quem abre a ficha encontra o nível escrito.
  Widget buildRiskDot(SnakeRisk risk) {

    return Container(

      width: 10,
      height: 10,

      decoration: BoxDecoration(
        color: SnakeMarker.colorFor(risk),
        shape: BoxShape.circle,
      ),
    );
  }
}
