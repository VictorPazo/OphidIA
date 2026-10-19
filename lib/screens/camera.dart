import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:snakes_of_imt/screens/snake_information.dart';
import '../models/snake_model.dart';
import '../models/upload_result.dart';
import '../services/api_exceptions.dart';
import '../services/ia_service.dart';
import '../services/snake_info.dart';
import '../services/upload_service.dart';
import '../services/yolo_service.dart';
import '../theme/app_page_route.dart';
import '../theme/app_theme.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() =>
      _CameraPageState();
}

class _CameraPageState
    extends State<CameraPage> {

  CameraController? _controller;

  List<CameraDescription> cameras = [];

  int selectedCameraIndex = 0;

  FlashMode currentFlashMode =
  FlashMode.off;

  final ImagePicker _picker =
  ImagePicker();

  final UploadService uploadService = UploadService();

  final IAService iaService = IAService();

  final YoloService yoloService = YoloService();

  final SnakeInformationService
  snakeInformationService =
  SnakeInformationService();

  String? cameraErrorMessage;

  // 📸 CONFIRMAÇÃO
  // Em vez de um showDialog separado, a foto capturada/escolhida vira
  // um estado desta própria tela — isso permite que a navegação para
  // o resultado seja uma única transição (com Hero de verdade), em
  // vez de duas transições encadeadas (fechar diálogo + abrir tela).
  String? confirmImagePath;

  bool confirmFromGallery = false;

  bool isConfirming = false;

  // 🐍 DETECÇÃO YOLO
  // isDetecting cobre a janela entre a foto ser tirada/escolhida e o
  // YOLO responder se achou uma cobra ou não — usado só pra mostrar
  // um loading diferente do de isConfirming (que é o upload+IA).
  bool isDetecting = false;

  // 📸 CAPTURA EM ANDAMENTO
  // O plugin da câmera recusa uma segunda `takePicture` enquanto a primeira
  // não voltou, e a recusa vem como exceção. Entre o toque e a foto existe o
  // tempo do autofoco, que é justamente quando a pessoa toca de novo achando
  // que o botão não respondeu.
  bool capturando = false;

  static const String snakePhotoHeroTag = 'snake_photo_hero';

  @override
  void initState() {
    super.initState();

    setupCamera();

    WidgetsBinding.instance
        .addPostFrameCallback((_) {

      showTutorialPopup();
    });
  }

  Future<void> setupCamera() async {

    await loadInitialFlashPreference();

    await loadZoomHintPreference();

    await initCamera();
  }

  //CAMERA
  Future<void> initCamera() async {

    setState(() {
      cameraErrorMessage = null;
    });

    try {

      cameras = await availableCameras();

      if (cameras.isEmpty) {

        setState(() {
          cameraErrorMessage =
              "camera_not_found".tr();
        });

        return;
      }

      if (selectedCameraIndex >=
          cameras.length) {
        selectedCameraIndex = 0;
      }

      // A câmera antiga sai da tela ANTES de ser descartada. O descarte é
      // assíncrono, e qualquer redesenho no meio dele — o chip de zoom, o
      // flash, o próprio setState lá de cima — chamava CameraPreview sobre
      // uma controller já descartada, e a tela inteira virava o quadro
      // vermelho de erro. Acontecia ao trocar para a câmera frontal.
      // Com _controller nulo, o preview mostra o indicador de carregamento
      // até a câmera nova ficar pronta.
      final antiga = _controller;
      if (mounted) {
        setState(() {
          _controller = null;
        });
      }
      await antiga?.dispose();

      _controller = CameraController(
        cameras[selectedCameraIndex],
        ResolutionPreset.medium,
      );

      await _controller!.initialize();

      // 🔦 FLASH
      // Reaplica o modo de flash atual (definido pela preferência
      // salva na primeira vez, ou pelo toggle manual do usuário nas
      // trocas seguintes) na nova controller — cada CameraController
      // criada não herda o flash da anterior.
      try {
        await _controller!.setFlashMode(
          currentFlashMode,
        );
      } catch (e) {
        // Câmeras sem flash (ex: frontal) rejeitam o modo — ignora.
      }

      // Os limites de zoom pertencem à controller, então são relidos a cada
      // troca de câmera: a frontal costuma ter faixa diferente da traseira.
      await loadZoomLimits();

      setState(() {});

    } on CameraException catch (e) {

      final bool permissionDenied =
          e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.code == 'CameraAccessRestricted';

      setState(() {

        cameraErrorMessage = permissionDenied

            ? "camera_permission_denied".tr()
            : "camera_generic_error".tr();
      });

    } catch (e) {

      setState(() {
        cameraErrorMessage =
            "camera_generic_error".tr();
      });
    }
  }

  // 🔦 FLASH PADRÃO
  // Lê a preferência salva em Configurações apenas uma vez, ao abrir
  // a câmera — depois disso, o controle manual na própria tela (item
  // 18) passa a mandar no modo de flash pela sessão.
  Future<void> loadInitialFlashPreference() async {

    final prefs =
    await SharedPreferences.getInstance();

    final bool autoFlash =
        prefs.getBool('autoFlash') ?? false;

    currentFlashMode = autoFlash
        ? FlashMode.always
        : FlashMode.off;
  }

  IconData flashIcon() {

    if (currentFlashMode == FlashMode.auto) {
      return Icons.flash_auto;
    }

    if (currentFlashMode == FlashMode.torch ||
        currentFlashMode == FlashMode.always) {
      return Icons.flash_on;
    }

    return Icons.flash_off;
  }

  // 🔦 ALTERNAR FLASH
  Future<void> toggleFlash() async {

    if (_controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    final FlashMode nextMode;

    if (currentFlashMode == FlashMode.off) {
      nextMode = FlashMode.auto;
    } else if (currentFlashMode ==
        FlashMode.auto) {
      nextMode = FlashMode.torch;
    } else {
      nextMode = FlashMode.off;
    }

    try {

      await _controller!.setFlashMode(
        nextMode,
      );

      setState(() {
        currentFlashMode = nextMode;
      });

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        SnackBar(
          content: Text(
            "flash_unavailable".tr(),
          ),
        ),
      );
    }
  }

  // 🔍 ZOOM
  //
  // Limites e nível atual. O mínimo e o máximo vêm do próprio sensor, porque
  // variam por aparelho e por lente — pedir um valor fora da faixa lança
  // exceção.
  double zoomMinimo = 1.0;
  double zoomMaximo = 1.0;
  double zoomAtual = 1.0;

  // Guarda o zoom de quando a pinça começou. Sem isso, cada atualização
  // multiplicaria a escala sobre o valor já alterado, e o zoom dispararia
  // ao primeiro movimento.
  double zoomAoIniciarPinca = 1.0;

  Future<void> loadZoomLimits() async {
    if (_controller == null) return;
    try {
      zoomMinimo = await _controller!.getMinZoomLevel();
      zoomMaximo = await _controller!.getMaxZoomLevel();
      zoomAtual = zoomMinimo;
    } catch (e) {
      // Câmera sem controle de zoom: os limites ficam em 1.0 e a pinça
      // simplesmente não faz nada.
      zoomMinimo = zoomMaximo = zoomAtual = 1.0;
    }
  }

  void handleZoomStart(ScaleStartDetails details) {
    zoomAoIniciarPinca = zoomAtual;
  }

  Future<void> handleZoomUpdate(ScaleUpdateDetails details) =>
      applyZoom(zoomAoIniciarPinca * details.scale);

  /// Caminho único para mexer no zoom, usado pela pinça e pelo chip.
  Future<void> applyZoom(double bruto) async {

    if (_controller == null ||
        !_controller!.value.isInitialized ||
        !temZoom) {
      return;
    }

    final alvo = bruto.clamp(zoomMinimo, zoomMaximo);

    // Ignora variação imperceptível: a pinça dispara muitas atualizações por
    // segundo, e cada chamada ao sensor tem custo.
    if ((alvo - zoomAtual).abs() < 0.01) return;

    try {
      await _controller!.setZoomLevel(alvo);
      if (!mounted) return;
      setState(() {
        zoomAtual = alvo;
      });
    } catch (e) {
      // Aparelho recusou o nível pedido — mantém o atual.
    }
  }

  /// O aparelho tem faixa de zoom usável? Câmeras simples devolvem mínimo e
  /// máximo iguais, e aí não há controle nenhum a oferecer.
  bool get temZoom => zoomMaximo > zoomMinimo + 0.05;

  /// "1x" quando o nível é inteiro, "1.5x" quando não — como nas câmeras
  /// nativas, que nunca escrevem "1.0x".
  String get zoomLabel {
    final n = (zoomAtual * 10).round() / 10;
    return n == n.roundToDouble()
        ? '${n.toInt()}x'
        : '${n.toStringAsFixed(1)}x';
  }

  /// Paradas de zoom do chip. Só entram as que o aparelho alcança, porque
  /// pedir nível fora da faixa lança exceção.
  List<double> zoomStops() {
    final paradas = <double>[zoomMinimo];
    for (final parada in const [2.0, 4.0]) {
      if (parada > zoomMinimo + 0.05 && parada < zoomMaximo - 0.05) {
        paradas.add(parada);
      }
    }
    return paradas;
  }

  /// Avança para a próxima parada, voltando ao mínimo depois da última.
  ///
  /// A pinça já funcionava, mas exigia que a pessoa adivinhasse que ela
  /// existe. Um chip que responde ao toque mostra o recurso a quem nunca
  /// tentaria dois dedos na tela.
  Future<void> cycleZoom() async {

    final paradas = zoomStops();
    if (paradas.length < 2) return;

    int atual = 0;
    for (int i = 0; i < paradas.length; i++) {
      if (zoomAtual >= paradas[i] - 0.05) atual = i;
    }

    await applyZoom(paradas[(atual + 1) % paradas.length]);
  }

  // 💡 DICA DE ZOOM
  // Mesmo padrão do histórico: aparece até a pessoa dispensar, e aí não volta
  // mais. Uma dica permanente viraria ruído depois do primeiro uso.
  bool showZoomHint = false;

  Future<void> loadZoomHintPreference() async {

    final prefs =
    await SharedPreferences.getInstance();

    final bool dismissed =
        prefs.getBool('cameraZoomHintDismissed') ?? false;

    if (!mounted) return;

    setState(() {
      showZoomHint = !dismissed;
    });
  }

  Future<void> dismissZoomHint() async {

    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setBool('cameraZoomHintDismissed', true);

    if (!mounted) return;

    setState(() {
      showZoomHint = false;
    });
  }

  // 🔄 TROCAR CÂMERA
  Future<void> switchCamera() async {

    if (cameras.length < 2) return;

    selectedCameraIndex =
        (selectedCameraIndex + 1) %
            cameras.length;

    await initCamera();
  }

  Future<void> showTutorialPopup() async {

    final prefs =
    await SharedPreferences.getInstance();

    bool naoMostrar =
        prefs.getBool(
          'naoMostrarTutorial',
        ) ??
            false;

    if (naoMostrar) return;

    bool checkValue = false;

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (context) {

        return StatefulBuilder(

          builder: (
              context,
              setState,
              ) {

            return Dialog(

              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  20,
                ),
              ),

              child: Container(

                padding:
                const EdgeInsets.all(AppSpacing.lg),

                decoration: BoxDecoration(

                  color: Colors.white,

                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),

                child: Column(

                  mainAxisSize:
                  MainAxisSize.min,

                  children: [

                    Text(

                      "tutorial_title".tr(),

                      style:
                      const TextStyle(

                        fontSize: 22,

                        fontWeight:
                        FontWeight.bold,

                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(
                      height: AppSpacing.md,
                    ),

                    Text(

                      "tutorial_text".tr(),

                      textAlign:
                      TextAlign.center,

                      style:
                      const TextStyle(
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(
                      height: AppSpacing.md,
                    ),

                    Row(

                      children: [

                        Checkbox(

                          value: checkValue,

                          onChanged: (
                              value,
                              ) {

                            setState(() {

                              checkValue =
                              value!;
                            });
                          },
                        ),

                        Expanded(

                          child: Text(

                            "tutorial_never_show"
                                .tr(),

                            style:
                            const TextStyle(
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),

                    ElevatedButton(

                      onPressed: () async {

                        if (checkValue) {

                          await prefs.setBool(

                            'naoMostrarTutorial',

                            true,
                          );
                        }

                        Navigator.pop(
                          context,
                        );
                      },

                      child: Text(
                        "close".tr(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Traduz uma exceção técnica numa mensagem de erro específica.
  String _errorKeyFor(String step, Object e) {
    if (e is SocketException) return '${step}_no_internet';
    if (e is TimeoutException) return '${step}_timeout';
    if (e is ServerException) return '${step}_server_error';
    if (e is ClientException) return '${step}_client_error';
    return '${step}_generic_error';
  }

  void _showStepError(String step, Object e, StackTrace stackTrace) {
    final key = _errorKeyFor(step, e);

    debugPrint('[$step] erro: $e');
    debugPrint(stackTrace.toString());

    if (!mounted) return;

    setState(() => isConfirming = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(key.tr())),
    );
  }

  // 🐍 DETECÇÃO YOLO
  // Chamado logo após a foto ser tirada/escolhida. Não bloqueia a
  // exibição da foto (ela já aparece na tela de confirmação antes da
  // resposta chegar) — só decide, quando a resposta chega, se dá o
  // zoom no quadrado ou mostra o pop-up de "não achei".
  Future<void> runSnakeDetection(String imagePath) async {

    setState(() {
      isDetecting = true;
    });

    final result = await yoloService.detectSnake(
      File(imagePath),
    );

    if (!mounted) return;

    if (result == null) {

      // 🔌 Falha de rede ao chamar o YOLO — não trava o usuário por
      // causa disso; segue pro fluxo normal como se não tivesse
      // detecção nenhuma.
      setState(() {
        isDetecting = false;
      });

      return;
    }

    if (result.found) {

      // 📏 RECORTE DESLIGADO
      //
      // A hipótese era que recortar o fundo ajudaria o classificador. Medido
      // em 150 fotos reais, reproduzindo este mesmo fluxo, o efeito é o
      // contrário:
      //
      //   sem recorte   139/150 corretas (92,7%), confiança média 77,5%
      //   com recorte   128/150 corretas (85,3%), confiança média 73,6%
      //
      // Das 58 fotos efetivamente recortadas, o recorte CONSERTOU 1 e
      // ESTRAGOU 12. Não é ruído: doze para um.
      //
      // A causa é que o classificador foi treinado com fotos inteiras, com a
      // cobra em contexto. O recorte remove justamente o que ele aprendeu a
      // usar e entrega um enquadramento que ele nunca viu no treino.
      //
      // O YOLO continua valendo como FILTRO — avisar quando não há cobra
      // evidente na foto é um serviço real ao usuário. O que saiu foi ele
      // alimentar o classificador.
      //
      // Para religar, basta voltar a chamar cropToBoundingBox aqui; o método
      // segue intacto logo abaixo, com a guarda de 60% que ele já tinha.
      if (!mounted) return;

      setState(() {
        confirmImagePath = imagePath;
        isDetecting = false;
      });

    } else {

      setState(() {
        isDetecting = false;
      });

      showNoSnakeDialog();
    }
  }

  // 🔍 RECORTE (ZOOM)
  // Recorta a foto na região que o YOLO marcou, com 15% de margem
  // (um recorte exato na borda da detecção costuma cortar parte do
  // corpo da cobra). O resultado vira a nova confirmImagePath — ou
  // seja, é essa versão recortada que o usuário vê e que segue pro
  // classificador depois, não a foto inteira original.
  Future<String?> cropToBoundingBox(
      String imagePath,
      DetectionResult result,
      ) async {

    if (result.x1 == null ||
        result.y1 == null ||
        result.x2 == null ||
        result.y2 == null) {
      return null;
    }

    final boxWidth = result.x2! - result.x1!;
    final boxHeight = result.y2! - result.y1!;

    // 🔎 FOTO JÁ PRÓXIMA: NÃO RECORTAR
    //
    // O recorte existe para tirar fundo de foto distante, onde a cobra ocupa
    // pouco do quadro. Quando ela JÁ ocupa boa parte, aproximar mais só
    // remove o contexto de que o classificador depende.
    //
    // Medido recortando progressivamente a mesma foto de Spilotes pullatus:
    //
    //   foto inteira   9/10 corretas, 94% de confiança média
    //   50% do lado    9/10 corretas, 83%
    //   30% do lado    5/10 corretas, 80%
    //   20% do lado    1/10 correta,  35%   <- vira chute
    //
    // O modelo decide pelo PADRÃO DO CORPO (no caso da caninana, as faixas
    // amarelas e pretas ao longo do dorso). Num macro de cabeça esse sinal
    // não existe e sobram escamas genéricas, então ele responde espécies sem
    // parentesco nenhum. Recortar uma foto que já é close piora exatamente
    // isso.
    final areaBox = boxWidth * boxHeight;
    final areaFoto =
        result.imageWidth.toDouble() * result.imageHeight.toDouble();

    const ocupacaoMaxima = 0.60;

    if (areaFoto > 0 && areaBox / areaFoto >= ocupacaoMaxima) {
      // Devolve null: runSnakeDetection já trata isso mantendo a foto
      // original, que é justamente o que queremos aqui.
      return null;
    }

    try {

      final bytes = await File(imagePath).readAsBytes();

      final original = img.decodeImage(bytes);

      if (original == null) return null;

      const marginRatio = 0.15;

      final marginX = boxWidth * marginRatio;
      final marginY = boxHeight * marginRatio;

      final cropX1 = (result.x1! - marginX)
          .clamp(0, result.imageWidth.toDouble());

      final cropY1 = (result.y1! - marginY)
          .clamp(0, result.imageHeight.toDouble());

      final cropX2 = (result.x2! + marginX)
          .clamp(0, result.imageWidth.toDouble());

      final cropY2 = (result.y2! + marginY)
          .clamp(0, result.imageHeight.toDouble());

      final cropped = img.copyCrop(
        original,
        x: cropX1.round(),
        y: cropY1.round(),
        width: (cropX2 - cropX1).round(),
        height: (cropY2 - cropY1).round(),
      );

      final directory = await getTemporaryDirectory();

      final croppedPath =
          '${directory.path}/snake_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await File(croppedPath).writeAsBytes(
        img.encodeJpg(cropped, quality: 90),
      );

      return croppedPath;

    } catch (e) {

      // Se o recorte falhar por qualquer motivo, segue com a foto
      // original em vez de travar o fluxo.
      return null;
    }
  }

  // 🐍 POP-UP "NÃO ACHEI COBRA"
  // 🔍 DETECÇÃO SEM RESULTADO
  //
  // O detector erra por omissão: nas medições com 60 fotos reais ele deixa de
  // achar a cobra em cerca de 35% das imagens legítimas, normalmente quando o
  // animal está distante, camuflado ou mal iluminado. Ou seja, "não achei" é
  // uma INCERTEZA, não um veredito de que não há cobra na foto.
  //
  // Por isso o diálogo informa em vez de barrar, e é escrito para isso:
  //  - o título admite a incerteza, em vez de afirmar que não há cobra;
  //  - o texto separa detecção de identificação, que são etapas diferentes;
  //  - as dicas explicam o que costuma resolver, em vez de só avisar do erro;
  //  - os botões dizem o que vai acontecer, no lugar de "Sim" e "Não", que
  //    obrigavam o usuário a reler a pergunta para saber qual era qual.
  //
  // Seguir em frente continua sendo a ação primária: o classificador acerta
  // muitas fotos que o detector recusa.
  void showNoSnakeDialog() {

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (context) {

        return Dialog(

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          child: Container(

            padding: const EdgeInsets.all(AppSpacing.lg),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),

            child: Column(

              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                // Ícone em círculo suave: sinaliza "busca sem resultado" sem o
                // vermelho de erro, que daria a entender que algo falhou.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF0EC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search_off_rounded,
                    size: 26,
                    color: AppColors.accent,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  "no_snake_found_title".tr(),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                Text(
                  "no_snake_found_message".tr(),
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F5F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "no_snake_tips_title".tr(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      noSnakeTip("no_snake_tip_distance".tr()),
                      noSnakeTip("no_snake_tip_light".tr()),
                      noSnakeTip("no_snake_tip_frame".tr()),
                      noSnakeTip("no_snake_tip_body".tr()),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Ação primária: identificar assim mesmo. O classificador
                // acerta boa parte das fotos que o detector recusa, então
                // empurrar o usuário a repetir a foto seria o padrão errado.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("identify_anyway".tr()),
                  ),
                ),

                const SizedBox(height: AppSpacing.xs),

                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      retakePhoto();
                    },
                    child: Text("take_another_photo".tr()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget noSnakeTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 5,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> confirmPhoto() async {
    final String imagePath = confirmImagePath!;

    setState(() {
      isConfirming = true;
    });

    final uploadFuture = uploadService.uploadImage(File(imagePath));
    final predictionFuture = iaService.predictSnake(File(imagePath));

    // FIX: timeLimit adicionado — sem isso, getCurrentPosition() pode
    // nunca completar, travando o app. GPS é opcional para armazenar no banco.
    final positionFuture = Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    ).then<Position?>((position) => position)
        .catchError((e) {
      debugPrint('GPS indisponível, seguindo sem localização: $e');
      return null;
    });

    final UploadResult uploadResult;
    try {
      uploadResult = await uploadFuture;
    } catch (e, stackTrace) {
      _showStepError('upload', e, stackTrace);
      return;
    }

    // IA
    final Map<String, dynamic> prediction;
    try {
      prediction = await predictionFuture;
    } catch (e, stackTrace) {
      _showStepError('ai', e, stackTrace);
      return;
    }

    final specie = prediction['specie'] as String?;
    final confidence = prediction['confidence'];

    // COBRA
    // A busca é pelo NOME científico, e não pelo snake_id: o servidor de
    // inferência só mapeia id para as espécies escritas à mão no
    // SPECIE_TO_ID, enquanto o nome vem para todas as 246 que o modelo
    // reconhece. Assim, qualquer espécie já cadastrada na tabela `snakes`
    // exibe a ficha, sem precisar mexer no servidor.
    final SnakeModel? snake;
    try {
      snake = specie == null
          ? null
          : await snakeInformationService.getSnakeBySpecie(specie);
    } catch (e, stackTrace) {
      _showStepError('snake', e, stackTrace);
      return;
    }

    if (snake == null) {
      // Espécie identificada, mas ainda sem linha na tabela `snakes`.
      if (!mounted) return;
      setState(() => isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("fetch_snake_error".tr())),
      );
      return;
    }

    // GPS —  nunca bloqueia a exibição do resultado.
    final position = await positionFuture;

    if (!mounted) return;

    HapticFeedback.heavyImpact();

    Navigator.pushReplacement(
      context,
      AppPageRoute(
        builder: (_) =>
            SnakeInformationScreen(
              snake: snake!,
              confidence: (confidence as num).toDouble(),
              imageUrl: uploadResult.filePath,
              heroTag: snakePhotoHeroTag,
              latitude: position?.latitude,
              longitude: position?.longitude,

              // Top-3 do classificador. Servidores antigos não mandam o
              // campo, então a lista vazia é o padrão e a tela apenas não
              // exibe o bloco de alternativas.
              ranking: ((prediction['ranking'] as List?) ?? [])
                  .cast<Map<String, dynamic>>(),
            ),
        transition: AppTransition.slide,
      ),
    );
  }

  void retakePhoto() {

    setState(() {
      confirmImagePath = null;
      isDetecting = false;
    });
  }

  // 📸 TELA DE CONFIRMAÇÃO
  Widget buildConfirmScreen() {

    return Container(

      width: double.infinity,

      height: double.infinity,

      color: AppColors.background,

      child: SafeArea(

        child: Padding(

          padding:
          const EdgeInsets.all(AppSpacing.lg),

          child: Column(

            children: [

              Text(
                "confirm_title".tr(),

                style: AppTextStyles.screenTitle,
              ),

              const SizedBox(height: AppSpacing.lg),

              Expanded(

                child: Hero(

                  tag: snakePhotoHeroTag,

                  child: ClipRRect(

                    borderRadius:
                    BorderRadius.circular(20),

                    child: Image.file(

                      File(confirmImagePath!),

                      width: double.infinity,

                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // 🐍 DETECTANDO
              // Loading separado do de isConfirming: aqui o YOLO ainda
              // está checando se há cobra na foto, antes do usuário
              // poder confirmar o envio pro classificador.
              if (isDetecting) ...[

                const CircularProgressIndicator(
                  color: Colors.white,
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  "detecting_snake".tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                  ),
                ),

              ] else if (isConfirming) ...[

                // ⏳ PROCESSANDO
                const CircularProgressIndicator(
                  color: Colors.white,
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  "processing_image".tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                  ),
                ),
              ] else ...[

                // 🔥 CONFIRMAR
                SizedBox(

                  width: double.infinity,

                  child: ElevatedButton(

                    onPressed: confirmPhoto,

                    child: Text(

                      confirmFromGallery

                          ? "confirm_new_photo".tr()

                          : "confirm_capture".tr(),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // 🔄 NOVA FOTO
                SizedBox(

                  width: double.infinity,

                  child: TextButton(

                    style: TextButton.styleFrom(
                      foregroundColor:
                      AppColors.onBackground,
                    ),

                    onPressed: retakePhoto,

                    child: Text(

                      confirmFromGallery

                          ? "choose_new_photo".tr()

                          : "new_capture".tr(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 📸 FOTO
  Future<void> takePhoto() async {

    if (_controller == null ||
        !_controller!.value.isInitialized ||
        capturando) {
      return;
    }

    setState(() {
      capturando = true;
    });

    try {

      // O modo de flash já fica aplicado à controller em tempo real
      // pelo toggle da tela (toggleFlash) e ao trocar de câmera
      // (initCamera), então não precisa ser reaplicado aqui.

      final image =
      await _controller!.takePicture();

      HapticFeedback.mediumImpact();

      if (!mounted) return;

      setState(() {
        confirmImagePath = image.path;
        confirmFromGallery = false;
      });

      await runSnakeDetection(image.path);

    } on CameraException catch (e) {

      // Falha de captura não pode derrubar a tela. O aparelho recusa a foto
      // em situações legítimas — a câmera foi tomada por outro app, o
      // armazenamento encheu — e o usuário precisa poder tentar de novo.
      debugPrint('Falha ao capturar: ${e.code} ${e.description}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("camera_generic_error".tr())),
      );

    } finally {

      // Libera o botão mesmo quando a captura falhou: sem isto, um erro
      // deixaria a câmera inutilizável até sair e voltar para a tela.
      if (mounted) {
        setState(() {
          capturando = false;
        });
      }
    }
  }

  // 🖼️ GALERIA
  Future<void> pickFromGallery() async {

    // 📉 REDUZ ANTES DE ENVIAR
    //
    // A galeria devolvia o arquivo original, que num celular atual passa
    // tranquilamente de 6 MB — o limite de uma requisição no AWS Lambda. A
    // foto da câmera não tem esse problema porque já sai em resolução média.
    //
    // Reduzir não custa precisão nenhuma: o classificador redimensiona tudo
    // para 384 px antes de olhar, e o detector para 960. Mandar 4000 px de
    // largura é banda jogada fora, e o upload fica mais lento para o usuário.
    final XFile? image =

    await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (image != null) {

      setState(() {
        confirmImagePath = image.path;
        confirmFromGallery = true;
      });

      await runSnakeDetection(image.path);
    }
  }

  @override
  void dispose() {

    _controller?.dispose();

    super.dispose();
  }

  // ⚠️ ERRO DE CÂMERA
  Widget buildCameraError() {

    return Padding(

      padding:
      const EdgeInsets.symmetric(
        horizontal: 32,
      ),

      child: Column(

        mainAxisSize:
        MainAxisSize.min,

        children: [

          const Icon(

            Icons.no_photography,

            color: Colors.white,

            size: 60,
          ),

          const SizedBox(height: 16),

          Text(

            cameraErrorMessage!,

            textAlign: TextAlign.center,

            style: const TextStyle(

              color: Colors.white,

              fontSize: 16,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          ElevatedButton(

            onPressed: initCamera,

            child: Text(
              "try_again".tr(),
            ),
          ),
        ],
      ),
    );
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

      body: confirmImagePath != null
          ? buildConfirmScreen()
          : buildCameraScreen(context),
    );
  }

  // 📷 TELA DA CÂMERA
  Widget buildCameraScreen(BuildContext context) {

    return Stack(

        children: [

          // 📸 CAMERA
          Center(

            child:
            cameraErrorMessage != null

                ? buildCameraError()

                : _controller == null ||

                !_controller!
                    .value
                    .isInitialized

                ? const CircularProgressIndicator(
              color: Colors.white,
            )

                : Container(

              width:
              MediaQuery.of(context)
                  .size
                  .width * 0.8,

              decoration: BoxDecoration(

                borderRadius:
                BorderRadius.circular(
                  20,
                ),

                border: Border.all(

                  color: Colors.black,

                  width: 4,
                ),
              ),

              child: ClipRRect(

                borderRadius:
                BorderRadius.circular(
                  16,
                ),

                // O sensor da câmera reporta o aspect ratio em
                // orientação paisagem (largura > altura); como o app
                // é travado em retrato, invertemos (1 / aspectRatio)
                // para o preview não esticar/distorcer a imagem.
                child: AspectRatio(

                  aspectRatio:
                  1 /
                      _controller!
                          .value
                          .aspectRatio,

                  // 🔍 ZOOM POR PINÇA
                  // Serve à segurança antes de tudo: permite enquadrar o
                  // animal sem se aproximar dele. E ajuda a identificação
                  // pelo mesmo motivo — o modelo decide pelo padrão do corpo,
                  // e uma cobra distante ocupa poucos pixels do quadro.
                  //
                  // Diferente de recortar a foto depois, que medimos ser
                  // prejudicial: aproximar ANTES preserva a resolução, enquanto
                  // recortar DEPOIS joga pixels fora e tira o contexto.
                  child: GestureDetector(
                    onScaleStart: handleZoomStart,
                    onScaleUpdate: handleZoomUpdate,
                    child: CameraPreview(
                      _controller!,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 🔦 FLASH
          if (cameraErrorMessage == null)
            Positioned(

              top: 60,
              left: 20,

              child: Semantics(

                label: "toggle_flash".tr(),

                button: true,

                child: IconButton(

                  icon: Icon(
                    flashIcon(),
                    color: Colors.white,
                  ),

                  iconSize: 28,

                  onPressed: toggleFlash,
                ),
              ),
            ),

          // 🔄 TROCAR CÂMERA
          if (cameraErrorMessage == null &&
              cameras.length > 1)
            Positioned(

              top: 60,
              right: 20,

              child: Semantics(

                label: "switch_camera".tr(),

                button: true,

                child: IconButton(

                  icon: const Icon(
                    Icons.cameraswitch,
                    color: Colors.white,
                  ),

                  iconSize: 28,

                  onPressed: switchCamera,
                ),
              ),
            ),

          // 🔝 TOPO
          Positioned(

            top: 60,
            left: 0,
            right: 0,

            child: Center(

              child: Column(

                children: [

                  Image.asset(

                    'assets/UI-UX/logo.png',

                    width: 65,
                    height: 65,

                    fit: BoxFit.contain,
                  ),

                  const SizedBox(
                    height: AppSpacing.sm,
                  ),

                  Text(

                    "camera_capture".tr(),

                    style:
                    const TextStyle(

                      color: AppColors.onBackground,

                      fontSize: 22,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔍 CONTROLE DE ZOOM
          //
          // A pinça funciona desde o início, mas era invisível: sem nada na
          // tela, só descobria o zoom quem tentasse dois dedos por conta
          // própria. O chip resolve as duas pontas — mostra o nível atual e,
          // no toque, troca de nível, o que já revela que o recurso existe.
          //
          // Fica acima dos botões e FORA do quadro da câmera, de propósito:
          // um controle sobre o preview cobriria justamente o animal que a
          // pessoa está tentando enquadrar.
          //
          // Antes o indicador estava no topo centralizado, no mesmo lugar do
          // logotipo — que, sendo desenhado depois, pintava em cima dele. O
          // nível de zoom nunca chegou a aparecer.
          if (cameraErrorMessage == null && temZoom)
            Positioned(

              // Os 128 px não são arbitrários: no quadro de 80% da
              // largura, a faixa escura entre os botões e a borda do
              // enquadramento vai de 115 a ~228 px da base num celular comum
              // (medido num S25 FE). Chip e dica ocupam de 128 a 228 e cabem
              // ali inteiros, sem cobrir a imagem.
              //
              // Em telas bem curtas essa faixa encurta e os dois passam a
              // flutuar sobre o preview. Não há como evitar — num sensor 16:9
              // sobram só uns 40 px — e é o que as câmeras nativas fazem de
              // qualquer forma.
              bottom: 128,
              left: 0,
              right: 0,

              child: Center(

                child: Semantics(

                  label: "camera_zoom_change".tr(),

                  button: true,

                  child: Material(

                    color: Colors.black.withValues(alpha: 0.55),

                    shape: const StadiumBorder(),

                    child: InkWell(

                      customBorder: const StadiumBorder(),

                      onTap: cycleZoom,

                      child: Padding(

                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 7,
                        ),

                        child: Row(

                          mainAxisSize: MainAxisSize.min,

                          children: [

                            const Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 16,
                            ),

                            const SizedBox(width: 5),

                            Text(

                              zoomLabel,

                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 💡 DICA DO ZOOM
          // O texto diz para que serve, não só o gesto: aproximar com a lente
          // em vez de aproximar o corpo é o que importa aqui.
          if (cameraErrorMessage == null && temZoom && showZoomHint)
            Positioned(

              bottom: 172,
              left: AppSpacing.lg,
              right: AppSpacing.lg,

              child: Container(

                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),

                decoration: BoxDecoration(

                  color: AppColors.accent,

                  borderRadius: BorderRadius.circular(14),
                ),

                child: Row(

                  children: [

                    const Icon(
                      Icons.pinch,
                      color: AppColors.onBackground,
                      size: 20,
                    ),

                    const SizedBox(width: AppSpacing.sm),

                    Expanded(

                      child: Text(

                        "camera_zoom_hint".tr(),

                        style: const TextStyle(
                          color: AppColors.onBackground,
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                    ),

                    Semantics(

                      label: "dismiss_hint".tr(),

                      button: true,

                      child: IconButton(

                        icon: const Icon(
                          Icons.close,
                          color: AppColors.onBackground,
                          size: 18,
                        ),

                        padding: EdgeInsets.zero,

                        constraints: const BoxConstraints(),

                        onPressed: dismissZoomHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 🔘 BOTÕES
          Positioned(

            bottom: 30,
            left: 0,
            right: 0,

            child: Row(

              mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,

              children: [

                // 🖼️ GALERIA
                Semantics(

                  label: "open_gallery".tr(),

                  button: true,

                  child: IconButton(

                    icon: const Icon(

                      Icons.photo_library,

                      color: Colors.white,
                    ),

                    iconSize: 35,

                    onPressed:
                    pickFromGallery,
                  ),
                ),

                // 📸 FOTO
                // Enquanto a captura está em curso o botão apaga e para de
                // responder. A guarda em `takePhoto` já evita a exceção, mas
                // sozinha ela deixaria o botão parecendo quebrado: a pessoa
                // toca, nada muda na tela, e ela toca de novo.
                Material(

                  color: capturando
                      ? Colors.white54
                      : Colors.white,

                  shape: const CircleBorder(
                    side: BorderSide(
                      color: Colors.black,
                      width: 3,
                    ),
                  ),

                  child: InkWell(

                    customBorder: const CircleBorder(),

                    onTap: capturando ? null : takePhoto,

                    child: SizedBox(

                      width: 85,
                      height: 85,

                      child: capturando

                          ? const Padding(
                              padding: EdgeInsets.all(26),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.background,
                              ),
                            )

                          : const Icon(

                              Icons.camera_alt,

                              color: AppColors.background,

                              size: 35,
                            ),
                    ),
                  ),
                ),

                // 🏠 VOLTAR
                Semantics(

                  label: "back_to_home".tr(),

                  button: true,

                  child: IconButton(

                    icon: const Icon(

                      Icons.home,

                      color: Colors.white,
                    ),

                    iconSize: 35,

                    onPressed: () {

                      Navigator.pop(
                        context,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
    );
  }
}