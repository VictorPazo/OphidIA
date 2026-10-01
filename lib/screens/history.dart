import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/snake_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_page_route.dart';
import '../theme/animated_entrance.dart';
import '../theme/skeleton.dart';
import 'snake_information.dart';
import 'home.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() =>
      _HistoryPageState();
}

class _HistoryPageState
    extends State<HistoryPage> {

  final supabase =
      Supabase.instance.client;

  List<dynamic> historic = [];

  bool loading = true;

  bool showSwipeHint = false;

  @override
  void initState() {
    super.initState();

    loadHistoric();

    loadSwipeHintPreference();
  }

  // 👆 DICA DE ARRASTAR
  // Mostra um banner discreto na primeira visita explicando que dá
  // para arrastar um item para a esquerda para excluí-lo, já que o
  // Dismissible não deixa isso óbvio até o usuário tentar.
  Future<void> loadSwipeHintPreference() async {

    final prefs =
    await SharedPreferences.getInstance();

    final bool dismissed =
        prefs.getBool(
          'historySwipeHintDismissed',
        ) ??
            false;

    if (!mounted) return;

    setState(() {
      showSwipeHint = !dismissed;
    });
  }

  Future<void> dismissSwipeHint() async {

    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setBool(
      'historySwipeHintDismissed',
      true,
    );

    if (!mounted) return;

    setState(() {
      showSwipeHint = false;
    });
  }

  // 🔥 CARREGAR HISTÓRICO
  Future<void> loadHistoric() async {

    final user =
        supabase.auth.currentUser;

    if (user == null) return;

    try {

      final response =

      await supabase

          .from('snake_historic')

          .select('''
            *,
            snakes(*)
          ''')

          .eq(
        'profiles_id',
        user.id,
      )

          .order(
        'data_photo',
        ascending: false,
      );

      setState(() {

        historic = response;

        loading = false;
      });

    } catch (e) {

      debugPrint(
        "Erro histórico: $e",
      );
    }
  }

  // 🗑️ DELETAR
  // `snake_historic` é a mesma tabela que o mapa comunitário lê em
  // home.dart (sem filtro de usuário) — apagar aqui já é a exclusão real
  // do avistamento pra todo mundo, não uma cópia local. O `.select()`
  // depois do `.delete()` é o que permite detectar quando a RLS aceita o
  // delete mas não remove nenhuma linha (não é dono do registro, por
  // exemplo): sem checar isso, o Supabase não lança erro nenhum, e o item
  // pareceria excluído na tela mesmo continuando no banco e no mapa.
  Future<void> deleteHistoric(
      int id,
      ) async {

    try {

      final deletedRows = await supabase

          .from('snake_historic')

          .delete()

          .eq('id', id)

          .select();

      if (deletedRows.isEmpty) {
        throw Exception(
          'Nenhuma linha removida (RLS ou id inexistente).',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("history_deleted".tr())),
      );

      loadHistoric();

    } catch (e) {

      debugPrint(
        "Erro delete: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("delete_history_error".tr())),
      );

      // O Dismissible já tirou o item da lista na tela de forma otimista;
      // recarrega pra ele voltar a aparecer, já que na prática não foi
      // excluído.
      loadHistoric();
    }
  }

  // 📅 FORMATAR DATA
  String formatDate(String date) {

    final parsed =
    DateTime.parse(date);

    return
      "${parsed.day.toString().padLeft(2, '0')}/"
          "${parsed.month.toString().padLeft(2, '0')}/"
          "${parsed.year}";
  }

  // 👆 BANNER DA DICA
  Widget buildSwipeHint() {

    return Container(

      margin:
      const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),

      padding:
      const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),

      decoration: BoxDecoration(

        color: AppColors.accent,

        borderRadius:
        BorderRadius.circular(14),
      ),

      child: Row(

        children: [

          const Icon(

            Icons.swipe_left_alt,

            color: AppColors.onBackground,

            size: 22,
          ),

          const SizedBox(width: AppSpacing.sm),

          Expanded(

            child: Text(

              "swipe_to_delete_hint".tr(),

              style: const TextStyle(

                color: AppColors.onBackground,

                fontSize: 13,
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

              constraints:
              const BoxConstraints(),

              onPressed: dismissSwipeHint,
            ),
          ),
        ],
      ),
    );
  }

  // 🖼️ URL DA IMAGEM
  String getImageUrl(String path) {

    if (path.startsWith('http')) {
      return path;
    }

    return supabase.storage

        .from('user-history')

        .getPublicUrl(path);
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

      appBar: AppBar(

        backgroundColor: Colors.transparent,

        elevation: 0,

        centerTitle: true,

        leading: IconButton(

          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.onBackground,
          ),

          onPressed: () {

            Navigator.pushAndRemoveUntil(

              context,

              AppPageRoute(
                builder: (_) =>
                const HomePage(),
                transition: AppTransition.fade,
              ),

                  (route) => false,
            );
          },
        ),

        title: Text(
          "history".tr(),
        ),
      ),

      body: loading

          ? ListView.builder(

        padding:
        const EdgeInsets.all(AppSpacing.lg),

        itemCount: 4,

        itemBuilder: (context, index) {

          return const HistoryCardSkeleton();
        },
      )

          : historic.isEmpty

          ? Center(

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(

              Icons.history_toggle_off,

              size: 90,

              color: AppColors.onBackground
                  .withValues(alpha: 0.5),
            ),

            const SizedBox(height: AppSpacing.md),

            Text(

              "no_history".tr(),

              textAlign: TextAlign.center,

              style: const TextStyle(

                color: AppColors.onBackground,

                fontSize: 18,
              ),
            ),
          ],
        ),
      )

          : Column(

        children: [

          if (showSwipeHint)
            buildSwipeHint(),

          Expanded(

            child: ListView.builder(

              padding:
              const EdgeInsets.all(AppSpacing.lg),

              itemCount: historic.length,

              itemBuilder: (context, index) {

          final item = historic[index];

          final snake =
          item['snakes'];

          final imagePath =
          item['image_url'];

          final imageUrl =
          getImageUrl(imagePath);

          final date =
          item['data_photo'];

          return FadeSlideIn(

            delay: Duration(
              milliseconds:
              40 * (index > 8 ? 8 : index),
            ),

            child: Dismissible(

            key: Key(
              item['id'].toString(),
            ),

            direction:
            DismissDirection.endToStart,

            confirmDismiss: (_) async {

              return await showDialog(

                context: context,

                builder: (_) {

                  return AlertDialog(

                    title: Text(
                      "delete_history".tr(),
                    ),

                    content: Text(
                      "delete_history_text".tr(),
                    ),

                    actions: [

                      TextButton(

                        onPressed: () {

                          Navigator.pop(
                            context,
                            false,
                          );
                        },

                        child: Text(
                          "cancel".tr(),
                        ),
                      ),

                      ElevatedButton(

                        style:
                        ElevatedButton.styleFrom(

                          backgroundColor:
                          AppColors.danger,
                        ),

                        onPressed: () {

                          Navigator.pop(
                            context,
                            true,
                          );
                        },

                        child: Text(
                          "delete".tr(),
                        ),
                      ),
                    ],
                  );
                },
              );
            },

            onDismissed: (_) {

              HapticFeedback.mediumImpact();

              deleteHistoric(
                item['id'],
              );
            },

            background: Container(

              alignment:
              Alignment.centerRight,

              padding:
              const EdgeInsets.only(
                right: AppSpacing.lg,
              ),

              margin:
              const EdgeInsets.only(
                bottom: AppSpacing.lg,
              ),

              decoration: BoxDecoration(

                color: AppColors.danger,

                borderRadius:
                BorderRadius.circular(
                  20,
                ),
              ),

              child: const Icon(

                Icons.delete,

                color: Colors.white,

                size: 35,
              ),
            ),

            child: Container(

              margin:
              const EdgeInsets.only(
                bottom: AppSpacing.lg,
              ),

              decoration: BoxDecoration(

                borderRadius:
                BorderRadius.circular(
                  20,
                ),

                boxShadow: [

                  BoxShadow(

                    color:
                    Colors.black
                        .withValues(alpha: 0.08),

                    blurRadius: 10,

                    offset:
                    const Offset(0, 5),
                  ),
                ],
              ),

              child: Material(

                color: Colors.white,

                borderRadius:
                BorderRadius.circular(20),

                clipBehavior: Clip.antiAlias,

                child: InkWell(

                  onTap: () {

                    final snakeModel =
                    SnakeModel.fromMap(
                      snake,
                    );

                    Navigator.push(

                      context,

                      AppPageRoute(

                        builder: (_) =>
                            SnakeInformationScreen(

                              snake: snakeModel,

                              confidence: 0,

                              imageUrl:
                              imagePath,
                            ),

                        transition: AppTransition.slide,
                      ),
                    );
                  },

                  child: Column(

                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    // 🖼️ FOTO
                    ClipRRect(

                      borderRadius:
                      const BorderRadius.vertical(
                        top:
                        Radius.circular(
                          20,
                        ),
                      ),

                      child: Image.network(

                        imageUrl,

                        height: 220,

                        width: double.infinity,

                        fit: BoxFit.cover,

                        errorBuilder: (
                            context,
                            error,
                            stackTrace,
                            ) {

                          return Container(

                            height: 220,

                            color:
                            Colors.grey[300],

                            child: const Center(

                              child: Icon(

                                Icons.image_not_supported,

                                size: 50,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    Padding(

                      padding:
                      const EdgeInsets.all(
                        AppSpacing.md,
                      ),

                      child: Column(

                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [

                          // 🐍 NOME
                          Text(

                            snake['specie']
                                ?? "unknown_species".tr(),

                            style:
                            const TextStyle(

                              fontSize: 24,

                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: AppSpacing.md,
                          ),

                          // ☠️ VENENOSA
                          Row(

                            children: [

                              Icon(

                                snake['poisonous']
                                    == true

                                    ? Icons.warning
                                    : Icons.check_circle,

                                color:
                                snake['poisonous']
                                    == true

                                    ? Colors.red
                                    : Colors.green,
                              ),

                              const SizedBox(
                                width: AppSpacing.sm,
                              ),

                              Text(

                                snake['poisonous']
                                    == true

                                    ? "poisonous".tr()
                                    : "non_poisonous".tr(),

                                style:
                                const TextStyle(
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: AppSpacing.md,
                          ),

                          // 📅 DATA
                          Text(

                            formatDate(date),

                            style:
                            const TextStyle(

                              fontSize: 15,

                              color:
                              Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
          );
        },
      ),
          ),
        ],
      ),
    );
  }
}