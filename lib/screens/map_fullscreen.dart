import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_theme.dart';
import '../theme/map_overlays.dart';
import '../utils/sighting_marker.dart';
import '../utils/snake_risk.dart';

/// O mapa ocupando a tela inteira.
///
/// A caixa arredondada da tela inicial divide espaço com o resumo, os botões e
/// a navegação, e sobra pouca área para enxergar a distribuição dos
/// avistamentos. Aqui o mapa fica com tudo.
///
/// Recebe os marcadores já montados em vez de consultar o banco de novo: cada
/// pino baixa e desenha a foto da espécie, e repetir isso ao abrir a tela
/// cheia custaria uma espera que a tela inicial já pagou.
///
/// O filtro é o mesmo objeto da tela de origem, passado com o callback — as
/// duas visões concordam, e voltar para a inicial não desfaz o que foi
/// escolhido aqui.
class MapFullScreenPage extends StatefulWidget {

  final List<SightingMarker> avistamentos;
  final LatLng currentPosition;

  final int nearbyTotal;
  final int nearbyHighRisk;
  final double raioKm;
  final int janelaDias;

  final SnakeRisk? riskFilter;
  final ValueChanged<SnakeRisk?> onRiskFilterChanged;

  const MapFullScreenPage({
    super.key,
    required this.avistamentos,
    required this.currentPosition,
    required this.nearbyTotal,
    required this.nearbyHighRisk,
    required this.raioKm,
    required this.janelaDias,
    required this.riskFilter,
    required this.onRiskFilterChanged,
  });

  @override
  State<MapFullScreenPage> createState() => _MapFullScreenPageState();
}

class _MapFullScreenPageState extends State<MapFullScreenPage> {

  GoogleMapController? mapController;

  /// Cópia local do filtro: a tela precisa redesenhar na hora do toque, sem
  /// depender de a tela de origem reconstruir esta rota. O callback mantém a
  /// origem em sincronia.
  SnakeRisk? filtro;

  @override
  void initState() {
    super.initState();
    filtro = widget.riskFilter;
  }

  Set<Marker> get visiveis => {

        Marker(
          markerId: const MarkerId("usuario"),
          position: widget.currentPosition,
          infoWindow: InfoWindow(title: "you_are_here".tr()),
        ),

        for (final avistamento in widget.avistamentos)
          if (filtro == null || avistamento.risk == filtro)
            avistamento.marker,
      };

  void aplicarFiltro(SnakeRisk? risco) {
    setState(() => filtro = risco);
    widget.onRiskFilterChanged(risco);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.background,

      body: Stack(

        children: [

          Positioned.fill(

            child: GoogleMap(

              initialCameraPosition: CameraPosition(
                target: widget.currentPosition,
                zoom: 15,
              ),

              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,

              markers: visiveis,

              // Abre espaço para a legenda não cobrir o logotipo do Google
              // nem o botão de localização, que o Maps exige manter visíveis.
              padding: const EdgeInsets.only(bottom: 44),

              onMapCreated: (controller) {
                mapController = controller;
              },
            ),
          ),

          // O resumo desce um pouco para não brigar com o botão de fechar.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Align(
                alignment: Alignment.topCenter,
                child: MapProximitySummary(
                  total: widget.nearbyTotal,
                  highRisk: widget.nearbyHighRisk,
                  radiusKm: widget.raioKm,
                  days: widget.janelaDias,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: buildCloseButton(),
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: MapRiskLegend(
                selected: filtro,
                onSelect: aplicarFiltro,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCloseButton() {

    return Semantics(

      label: "map_exit_fullscreen".tr(),

      button: true,

      child: Material(

        color: Colors.white.withValues(alpha: 0.94),

        shape: const CircleBorder(),

        child: InkWell(

          customBorder: const CircleBorder(),

          onTap: () => Navigator.pop(context),

          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Icon(
              Icons.fullscreen_exit,
              color: Colors.black87,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
