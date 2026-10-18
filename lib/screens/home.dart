import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:snakes_of_imt/screens/snake_information.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/snake_model.dart';
import '../theme/app_page_route.dart';
import '../theme/app_theme.dart';
import '../theme/map_overlays.dart';
import '../theme/skeleton.dart';
import '../utils/sighting_marker.dart';
import '../utils/snake_marker.dart';
import '../utils/snake_risk.dart';
import '../utils/sighting_time.dart';
import 'camera.dart';
import 'configuration.dart';
import 'history.dart';
import 'map_fullscreen.dart';
import 'species_catalog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  int selectedIndex = 1;

  GoogleMapController? mapController;

  LatLng currentPosition =
  const LatLng(-23.55052, -46.633308);

  /// Avistamentos com o risco preservado ao lado do pino, para a legenda
  /// poder filtrar sem remontar os ícones.
  List<SightingMarker> avistamentos = [];

  /// Nível isolado pela legenda, ou null quando o mapa mostra todos.
  SnakeRisk? riskFilter;

  /// O que o mapa desenha: o marcador do usuário sempre, mais os
  /// avistamentos que passam pelo filtro. O marcador do usuário fica fora da
  /// lista justamente para nunca ser filtrado — ele não é um avistamento.
  Set<Marker> get visibleMarkers => {

        Marker(
          markerId: const MarkerId("usuario"),
          position: currentPosition,
          infoWindow: InfoWindow(title: "you_are_here".tr()),
        ),

        for (final avistamento in avistamentos)
          if (riskFilter == null || avistamento.risk == riskFilter)
            avistamento.marker,
      };

  bool loadingMap = true;

  // 📍 RESUMO DE PROXIMIDADE
  //
  // O mapa responde "onde tem cobra"; estes números respondem "é perigoso
  // aqui", que é a pergunta que a pessoa realmente tem ao abrir a tela.
  //
  // Os limites são escolhas de produto: 5 km é uma vizinhança a pé ou de carro
  // curto, e 30 dias é recente o bastante para ainda dizer algo. Um avistamento
  // de três anos atrás pesaria igual a um de ontem, e não deveria.
  static const double _raioKm = 5;
  static const int _janelaDias = 30;

  int nearbyTotal = 0;
  int nearbyHighRisk = 0;

  @override
  void initState() {
    super.initState();

    loadMap();
  }

  Future<void> loadMap() async {

    await getUserLocation();

    await loadSnakeMarkers();

    if (mapController != null) {

      await mapController!.animateCamera(

        CameraUpdate.newLatLngZoom(
          currentPosition,
          16,
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      loadingMap = false;
    });
  }

  Future<void> getUserLocation() async {

    bool serviceEnabled;

    LocationPermission permission;

    serviceEnabled =
    await Geolocator
        .isLocationServiceEnabled();

    if (!serviceEnabled) {

      showLocationWarning();

      return;
    }

    permission =
    await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {

      permission =
      await Geolocator.requestPermission();

      if (permission ==
          LocationPermission.denied) {

        showLocationWarning();

        return;
      }
    }

    if (permission ==
        LocationPermission.deniedForever) {

      showLocationWarning();

      return;
    }

    try {

      Position position =
      await Geolocator
          .getCurrentPosition();

      currentPosition = LatLng(
        position.latitude,
        position.longitude,
      );

    } catch (e) {

      showLocationWarning();
    }
  }

  // ⚠️ AVISO DE LOCALIZAÇÃO
  // Sem isso, o mapa ficava centralizado silenciosamente em São
  // Paulo (posição padrão) sempre que a localização não estivesse
  // disponível, sem o usuário entender o motivo.
  void showLocationWarning() {

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(

      SnackBar(
        content: Text(
          "location_unavailable_warning".tr(),
        ),

        duration:
        const Duration(seconds: 4),
      ),
    );
  }

  // 📄 DO MAPA PARA A FICHA
  // O avistamento no mapa já traz a linha inteira da espécie, porque a
  // consulta faz join com `snakes(*)`. Então dá para abrir a ficha completa
  // sem nenhuma ida extra ao banco.
  //
  // A confiança vai como 0, do mesmo jeito que no histórico: o número da
  // identificação pertence a quem tirou a foto, e mostrá-lo para outra
  // pessoa daria a entender que é uma medida daquele avistamento para ela.
  void abrirFicha(
      Map<String, dynamic> snake,
      Map<String, dynamic> registro,
      ) {

    final SnakeModel modelo;

    try {
      modelo = SnakeModel.fromMap(snake);
    } catch (e) {
      debugPrint("abrirFicha: linha de espécie inválida: $e");
      return;
    }

    Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => SnakeInformationScreen(
          snake: modelo,
          confidence: 0,
          imageUrl: (registro['image_url'] ?? '').toString(),
        ),
        transition: AppTransition.slide,
      ),
    );
  }

  void abrirMapaTelaCheia() {

    Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => MapFullScreenPage(
          avistamentos: avistamentos,
          currentPosition: currentPosition,
          nearbyTotal: nearbyTotal,
          nearbyHighRisk: nearbyHighRisk,
          raioKm: _raioKm,
          janelaDias: _janelaDias,
          riskFilter: riskFilter,
          // O filtro escolhido na tela cheia continua valendo ao voltar:
          // desfazer a escolha do usuário na transição seria perder trabalho
          // que ele acabou de fazer.
          onRiskFilterChanged: (risco) {
            if (!mounted) return;
            setState(() => riskFilter = risco);
          },
        ),
        transition: AppTransition.fade,
      ),
    );
  }

  /// Título da janela do marcador: o primeiro nome popular cadastrado, ou o
  /// científico quando a espécie ainda não tem nome popular.
  String nomeDoMarcador(Map<String, dynamic> snake) {

    final cientifico = snake['specie']?.toString() ?? '';

    try {
      return SnakeModel.fromMap(snake)
              .localizedPopularNameMain(context.locale.languageCode) ??
          cientifico;
    } catch (_) {
      // Linha incompleta no banco não pode tirar o avistamento do mapa.
      return cientifico;
    }
  }

  Future<void> loadSnakeMarkers() async {

    try {

      final response =
      await Supabase.instance.client

          .from('snake_historic')

          .select('''
          *,
          snakes(*)
        ''');

      // O marcador do usuário não entra aqui: ele é montado em
      // `visibleMarkers`, porque não é um avistamento e nunca deve ser
      // removido pelo filtro da legenda.
      final List<SightingMarker> carregados = [];

      int perto = 0;
      int pertoAlto = 0;

      for (var item in response) {

        if (item['latitude'] == null ||
            item['longitude'] == null) {
          continue;
        }

        final snake = item['snakes'];

        if (snake == null) continue;

        final bool poisonous = snake['poisonous'] == true;

        // O nível vem da dentição, a mesma regra da ficha. Quando a dentição
        // não é reconhecida (inclusive quando o campo está como "REVISAR" no
        // banco), caímos no booleano de peçonhenta, que é a informação menos
        // precisa mas sempre presente.
        final SnakeRisk risk =
            riskFromDentition(snake['dentition_type']?.toString() ?? '') ??
                (poisonous ? SnakeRisk.high : SnakeRisk.low);

        final String imageName =
            (snake['image_name'] ?? '').toString();

        final String fotoEspecie = imageName.isEmpty
            ? ''
            : Supabase.instance.client.storage
                .from('snake-species')
                .getPublicUrl(imageName);

        // 🐍 MARCADOR COM A CARA DA ESPÉCIE
        // Substitui o pino vermelho genérico. A borda colorida separa
        // peçonhenta de não peçonhenta à distância, e a foto deixa a espécie
        // reconhecível sem precisar tocar em nada.
        final icone = await SnakeMarker.build(
          cacheKey: snake['specie']?.toString() ?? 'desconhecida',
          imageUrl: fotoEspecie,
          risk: risk,
        );

        // ⏱️ "VISTO HÁ X" SÓ NO TOQUE
        // Fica de fora do pino (que já carrega foto + borda de cor) e só
        // aparece dentro do InfoWindow, junto com as outras informações —
        // o mapa continua limpo, sem rótulo permanente sobre o marcador.
        String? sightedAgo;
        final dataPhoto = item['data_photo']?.toString();
        if (dataPhoto != null) {
          try {
            sightedAgo = sightingTimeAgoKey(DateTime.parse(dataPhoto)).tr();
          } catch (e) {
            debugPrint("Erro ao calcular tempo do avistamento: $e");
          }
        }

        final posicao = LatLng(
          double.parse(item['latitude'].toString()),
          double.parse(item['longitude'].toString()),
        );

        // Conta para o resumo de proximidade. Feito aqui, no mesmo laço, para
        // não percorrer a lista duas vezes nem consultar o banco de novo.
        if (dataPhoto != null) {
          try {
            final idade = DateTime.now()
                .difference(DateTime.parse(dataPhoto))
                .inDays;

            final metros = Geolocator.distanceBetween(
              currentPosition.latitude,
              currentPosition.longitude,
              posicao.latitude,
              posicao.longitude,
            );

            if (idade <= _janelaDias && metros <= _raioKm * 1000) {
              perto++;
              if (risk == SnakeRisk.high) pertoAlto++;
            }
          } catch (e) {
            debugPrint("Erro ao contar avistamento próximo: $e");
          }
        }

        carregados.add(

          SightingMarker(

            risk: risk,

            marker: Marker(

            markerId:
            MarkerId(
              "snake_${item['id']}",
            ),

            position: posicao,

            icon: icone,

            infoWindow: InfoWindow(

              // Nome popular no título: quem olha o mapa procura o que foi
              // visto perto de casa e reconhece "jararaca" antes de
              // Bothrops jararaca. O científico não cabe junto — a janela
              // corta o que passa da largura e empurraria para fora o "toque
              // para ver", que é o que ensina que ela abre a ficha. Ele fica
              // a um toque, logo abaixo do título da ficha.
              title: nomeDoMarcador(snake),

              // A cor sozinha não basta: parte das pessoas não distingue
              // vermelho de verde, então o texto sempre repete o risco. O
              // "toque para ver" ensina que a janela abre a ficha — sem
              // isso ninguém descobre.
              snippet: [
                poisonous ? "poisonous_yes".tr() : "poisonous_no".tr(),
                ?sightedAgo,
                "tap_to_open".tr(),
              ].join(" · "),

              onTap: () => abrirFicha(snake, item),
            ),
            ),
          ),
        );
      }

      setState(() {

        avistamentos = carregados;
        nearbyTotal = perto;
        nearbyHighRisk = pertoAlto;
      });

    } catch (e) {

      debugPrint(
        "Erro markers: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        SnackBar(
          content: Text(
            "load_markers_error".tr(),
          ),
        ),
      );
    }
  }

  void onItemTapped(int index) {

    switch (index) {

      case 0:

        Navigator.push(

          context,

          AppPageRoute(
            builder: (_) =>
            const ConfigurationPage(),
            transition: AppTransition.slide,
          ),
        );

        break;

      case 2:

        Navigator.push(

          context,

          AppPageRoute(
            builder: (_) =>
            const HistoryPage(),
            transition: AppTransition.slide,
          ),
        ).then((_) {

          loadMap();
        });

        break;

      case 3:

        Navigator.push(

          context,

          AppPageRoute(
            builder: (_) =>
            const CameraPage(),
            transition: AppTransition.slide,
          ),
        ).then((_) {

          loadMap();
        });

        break;
    }
  }

  @override
  Widget build(BuildContext context) {

    // Chaves usadas como "chave".tr() (sem passar `context:`) leem um
    // singleton global do easy_localization, não um InheritedWidget — essa
    // tela só reconstrói sozinha quando o idioma muda se também depender de
    // context.locale, senão o texto só atualiza na próxima vez que a tela
    // for recriada do zero (ex: ao sair e voltar pra ela).
    context.locale;

    return Scaffold(

      body: Column(

        children: [

          const SizedBox(height: 80),

          Column(

            children: [

              Image.asset(

                'assets/UI-UX/logo.png',

                width: 90,
                height: 90,

                fit: BoxFit.contain,
              ),

              const SizedBox(height: AppSpacing.sm),

              const Text(

                "OphidIA",

                style: AppTextStyles.screenTitle,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          Expanded(

            child: Padding(

              padding:
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),

              child: loadingMap

                  ? const MapSkeleton()

              // 🗺️ SOBREPOSIÇÕES
              // O resumo fica no topo porque é a resposta; a legenda fica no
              // rodapé porque é consulta, não informação principal. Ambas
              // dentro do ClipRRect, para acompanharem os cantos do mapa.
                  : ClipRRect(

                borderRadius:
                BorderRadius.circular(20),

                child: Stack(

                  children: [

                    Positioned.fill(

                      child: GoogleMap(

                        initialCameraPosition:

                        CameraPosition(

                          target:
                          currentPosition,

                          zoom: 17,
                        ),

                        myLocationEnabled: true,

                        myLocationButtonEnabled: true,

                        zoomControlsEnabled: false,

                        markers: visibleMarkers,

                        // Empurra para cima o logotipo do Google e os
                        // controles, que o Maps exige manter visiveis, para
                        // que a legenda do rodape nao os cubra.
                        padding:
                        const EdgeInsets.only(bottom: 44),

                        onMapCreated: (controller) {

                          mapController = controller;
                        },
                      ),
                    ),

                    Align(

                      alignment: Alignment.topCenter,

                      child: MapProximitySummary(

                        total: nearbyTotal,
                        highRisk: nearbyHighRisk,
                        radiusKm: _raioKm,
                        days: _janelaDias,
                      ),
                    ),

                    Align(

                      alignment: Alignment.bottomCenter,

                      child: MapRiskLegend(
                        selected: riskFilter,
                        onSelect: (risco) {
                          setState(() => riskFilter = risco);
                        },
                      ),
                    ),

                    // ⛶ TELA CHEIA
                    // Canto oposto ao do resumo, para os dois não brigarem.
                    // A caixa arredondada divide espaço com o resumo, os
                    // botões e a navegação; para ler a distribuição dos
                    // avistamentos é preciso o mapa inteiro.
                    Align(

                      alignment: Alignment.topRight,

                      child: Padding(

                        padding: const EdgeInsets.all(AppSpacing.sm),

                        child: Semantics(

                          label: "map_open_fullscreen".tr(),

                          button: true,

                          child: Material(

                            color: Colors.white.withValues(alpha: 0.94),

                            shape: const CircleBorder(),

                            child: InkWell(

                              customBorder: const CircleBorder(),

                              onTap: abrirMapaTelaCheia,

                              child: const Padding(
                                padding: EdgeInsets.all(7),
                                child: Icon(
                                  Icons.fullscreen,
                                  color: Colors.black87,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Padding(

            padding:
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),

            child: Material(

              color: AppColors.accent,

              borderRadius:
              BorderRadius.circular(20),

              child: InkWell(

                borderRadius:
                BorderRadius.circular(20),

                onTap: () {

                  Navigator.push(

                    context,

                    AppPageRoute(
                      builder: (_) =>
                      const CameraPage(),
                      transition: AppTransition.slide,
                    ),
                  ).then((_) {

                    loadMap();
                  });
                },

                child: SizedBox(

                  width: double.infinity,

                  height: 90,

                  child: Row(

                    mainAxisAlignment:
                    MainAxisAlignment.center,

                    children: [

                      const Icon(

                        Icons.camera_alt,

                        color: Colors.white,

                        size: 35,
                      ),

                      const SizedBox(width: AppSpacing.md),

                      Text(

                        "identify_snake".tr(),

                        style:
                        AppTextStyles.sectionTitle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // 📖 CATÁLOGO
          // Entrada deliberadamente secundária: identificar é o que o app faz,
          // consultar é o que ele também permite. Um botão do mesmo peso que o
          // de identificar competiria com ele e confundiria o propósito da
          // tela.
          Padding(

            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),

            child: Material(

              color: Colors.white.withValues(alpha: 0.08),

              borderRadius: BorderRadius.circular(16),

              child: InkWell(

                borderRadius: BorderRadius.circular(16),

                onTap: () {

                  Navigator.push(
                    context,
                    AppPageRoute(
                      builder: (_) => const SpeciesCatalogPage(),
                      transition: AppTransition.slide,
                    ),
                  );
                },

                child: SizedBox(

                  width: double.infinity,

                  height: 52,

                  child: Row(

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [

                      const Icon(
                        Icons.menu_book_outlined,
                        color: AppColors.onBackground,
                        size: 20,
                      ),

                      const SizedBox(width: AppSpacing.sm),

                      Text(
                        "catalog_open".tr(),
                        style: const TextStyle(
                          color: AppColors.onBackground,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(

        currentIndex: selectedIndex,

        onTap: onItemTapped,

        items: [

          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: "settings".tr(),
          ),

          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: "home".tr(),
          ),

          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: "history".tr(),
          ),

          BottomNavigationBarItem(
            icon: const Icon(Icons.camera_alt),
            label: "camera".tr(),
          ),
        ],
      ),
    );
  }
}