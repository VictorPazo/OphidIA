import 'package:easy_localization/easy_localization.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/snake_model.dart';
import '../utils/snake_marker.dart';
import 'screens.dart';

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

  Set<Marker> markers = {};

  bool loadingMap = true;

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

  Future<void> loadSnakeMarkers() async {

    try {

      final response =
      await Supabase.instance.client

          .from('snake_historic')

          .select('''
          *,
          snakes(*)
        ''');

      Set<Marker> loadedMarkers = {};

      loadedMarkers.add(

        Marker(

          markerId:
          const MarkerId("usuario"),

          position: currentPosition,

          infoWindow: InfoWindow(
            title: "Você está aqui",
          ),
        ),
      );

      for (var item in response) {

        if (item['latitude'] == null ||
            item['longitude'] == null) {
          continue;
        }

        final snake = item['snakes'];

        if (snake == null) continue;

        final bool poisonous = snake['poisonous'] == true;

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
          poisonous: poisonous,
        );

        loadedMarkers.add(

          Marker(

            markerId:
            MarkerId(
              "snake_${item['id']}",
            ),

            position: LatLng(

              double.parse(
                item['latitude'].toString(),
              ),

              double.parse(
                item['longitude'].toString(),
              ),
            ),

            icon: icone,

            infoWindow: InfoWindow(

              title:
              snake['specie'],

              // A cor sozinha não basta: parte das pessoas não distingue
              // vermelho de verde, então o texto sempre repete o risco. O
              // "toque para ver" ensina que a janela abre a ficha — sem
              // isso ninguém descobre.
              snippet: poisonous
                  ? "${"poisonous_yes".tr()} · ${"tap_to_open".tr()}"
                  : "${"poisonous_no".tr()} · ${"tap_to_open".tr()}",

              onTap: () => abrirFicha(snake, item),
            ),
          ),
        );
      }

      setState(() {

        markers = loadedMarkers;
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

                  : ClipRRect(

                borderRadius:
                BorderRadius.circular(20),

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

                  markers: markers,

                  onMapCreated: (controller) {

                    mapController = controller;
                  },
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