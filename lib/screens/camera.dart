import 'dart:async';
import 'dart:io';
import '../models/snake_model.dart';
import '../models/upload_result.dart';
import '../services/api_exceptions.dart';
import '../services/upload_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/services.dart';
import '../screens/screens.dart';

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

  final UploadService uploadService =
  UploadService();

  final IAService iaService =
  IAService();

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

      await _controller?.dispose();

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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
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

    final snakeId = prediction['snake_id'];
    final confidence = prediction['confidence'];

    // COBRA
    final SnakeModel? snake;
    try {
      snake = snakeId == null
          ? null
          : await snakeInformationService.getSnakeById(snakeId);
    } catch (e, stackTrace) {
      _showStepError('snake', e, stackTrace);
      return;
    }

    if (snake == null) {
      // snake_id null (espécie não cadastrada).
      if (!mounted) return;
      setState(() => isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("fetch_snake_error".tr())),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

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
            ),
        transition: AppTransition.slide,
      ),
    );
  }

  void retakePhoto() {

    setState(() {
      confirmImagePath = null;
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

              // ⏳ PROCESSANDO
              if (isConfirming) ...[

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

    if (_controller != null &&
        _controller!.value.isInitialized) {

      // O modo de flash já fica aplicado à controller em tempo real
      // pelo toggle da tela (toggleFlash) e ao trocar de câmera
      // (initCamera), então não precisa ser reaplicado aqui.

      final image =
      await _controller!.takePicture();

      HapticFeedback.mediumImpact();

      setState(() {
        confirmImagePath = image.path;
        confirmFromGallery = false;
      });
    }
  }

  // 🖼️ GALERIA
  Future<void> pickFromGallery() async {

    final XFile? image =

    await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image != null) {

      setState(() {
        confirmImagePath = image.path;
        confirmFromGallery = true;
      });
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

                  child: CameraPreview(
                    _controller!,
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
                Material(

                  color: Colors.white,

                  shape: const CircleBorder(
                    side: BorderSide(
                      color: Colors.black,
                      width: 3,
                    ),
                  ),

                  child: InkWell(

                    customBorder: const CircleBorder(),

                    onTap: takePhoto,

                    child: const SizedBox(

                      width: 85,
                      height: 85,

                      child: Icon(

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