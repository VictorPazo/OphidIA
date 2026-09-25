import 'package:flutter/material.dart';
import '../theme/app_page_route.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/ibge_service.dart';
import 'login.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() =>
      _CadastroPageState();
}

class _CadastroPageState
    extends State<CadastroPage> {

  final TextEditingController nomeController =
  TextEditingController();

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController senhaController =
  TextEditingController();

  final TextEditingController
  confirmaSenhaController =
  TextEditingController();

  bool mostrarSenha = false;

  bool mostrarConfirmarSenha = false;

  String? estadoSelecionado;

  String? cidadeSelecionada;

  final TextEditingController cidadeBuscaController =
  TextEditingController();

  bool tentouCadastrar = false;

  bool isRegistering = false;

  final List<String> estados = [

    'AC','AL','AP','AM','BA','CE','DF','ES',
    'GO','MA','MT','MS','MG','PA','PB','PR',
    'PE','PI','RJ','RN','RS','RO','RR','SC',
    'SP','SE','TO'
  ];

  List<String> cidades = [];

  bool get nomeInvalido =>
      tentouCadastrar &&
          nomeController.text.trim().isEmpty;

  bool get emailInvalido {

    if (!tentouCadastrar) return false;

    final email =
    emailController.text.trim();

    return email.isEmpty ||
        !email.contains('@');
  }

  bool get senhaInvalida =>
      tentouCadastrar &&
          senhaController.text.length < 6;

  bool get confirmaSenhaInvalida =>
      tentouCadastrar &&
          confirmaSenhaController.text !=
              senhaController.text;

  bool get estadoInvalido =>
      tentouCadastrar &&
          estadoSelecionado == null;

  bool get cidadeInvalida =>
      tentouCadastrar &&
          cidadeSelecionada == null;

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: SafeArea(

        child: Column(

          children: [

            const SizedBox(height: AppSpacing.lg),

            const Text(

              "Cadastro",

              style: TextStyle(

                color: AppColors.onBackground,

                fontSize: 22,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Expanded(

              child: Container(

                padding:
                const EdgeInsets.all(AppSpacing.lg),

                decoration:
                const BoxDecoration(

                  color: Colors.white,

                  borderRadius:
                  BorderRadius.vertical(

                    top:
                    Radius.circular(25),
                  ),
                ),

                child: SingleChildScrollView(

                  child: Column(

                    children: [

                      buildField(

                        "Nome",

                        nomeController,

                        error:
                        nomeInvalido,
                      ),

                      buildField(

                        "Email",

                        emailController,

                        error:
                        emailInvalido,
                      ),

                      buildField(

                        "Senha",

                        senhaController,

                        isPassword: true,

                        mostrarSenha:
                        mostrarSenha,

                        error:
                        senhaInvalida,

                        onTogglePassword: () {

                          setState(() {

                            mostrarSenha =
                            !mostrarSenha;
                          });
                        },
                      ),

                      buildField(

                        "Confirmar senha",

                        confirmaSenhaController,

                        isPassword: true,

                        mostrarSenha:
                        mostrarConfirmarSenha,

                        error:
                        confirmaSenhaInvalida,

                        onTogglePassword: () {

                          setState(() {

                            mostrarConfirmarSenha =
                            !mostrarConfirmarSenha;
                          });
                        },
                      ),

                      Padding(

                        padding:
                        const EdgeInsets.only(
                          bottom: AppSpacing.md,
                        ),

                        child:
                        DropdownButtonFormField<String>(

                          value:
                          estadoSelecionado,

                          decoration:
                          InputDecoration(

                            labelText:
                            'Estado',

                            errorText:
                            estadoInvalido

                                ? 'Selecione um estado'
                                : null,

                            enabledBorder:
                            OutlineInputBorder(

                              borderRadius:
                              BorderRadius.circular(10),

                              borderSide:
                              BorderSide(

                                color:
                                estadoInvalido

                                    ? Colors.red
                                    : Colors.grey,
                              ),
                            ),

                            focusedBorder:
                            OutlineInputBorder(

                              borderRadius:
                              BorderRadius.circular(10),

                              borderSide:
                              BorderSide(

                                color:
                                estadoInvalido

                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                          ),

                          items:
                          estados.map((estado) {

                            return DropdownMenuItem(

                              value: estado,

                              child: Text(
                                estado,
                              ),
                            );
                          }).toList(),

                          onChanged:
                              (value) async {

                            setState(() {

                              estadoSelecionado =
                                  value;

                              cidadeSelecionada =
                              null;

                              // 🔎 BUSCA CIDADE
                              // Limpa o texto digitado no campo de busca
                              // sempre que o estado muda, já que a lista
                              // de cidades válidas também mudou.
                              cidadeBuscaController.clear();

                              cidades = [];
                            });

                            if (value != null) {

                              final ibgeService =
                              IbgeService();

                              final cidadesIBGE =

                              await ibgeService
                                  .buscarCidades(
                                value,
                              );

                              setState(() {

                                cidades =
                                    cidadesIBGE;
                              });
                            }
                          },
                        ),
                      ),

                      // 🔎 BUSCA CIDADE
                      // Substitui o DropdownButtonFormField de Cidade por um
                      // Autocomplete que filtra a lista `cidades` (já carregada
                      // pelo IbgeService) conforme o usuário digita.
                      Padding(

                        padding:
                        const EdgeInsets.only(
                          bottom: AppSpacing.md,
                        ),

                        child: Autocomplete<String>(

                          optionsBuilder: (TextEditingValue textEditingValue) {

                            // Se nenhum estado foi escolhido ainda, não há
                            // o que sugerir.
                            if (cidades.isEmpty) {
                              return const Iterable<String>.empty();
                            }

                            final query = textEditingValue.text.toLowerCase();

                            if (query.isEmpty) {
                              return cidades;
                            }

                            return cidades.where((cidade) {
                              return cidade.toLowerCase().contains(query);
                            });
                          },

                          onSelected: (String selecao) {

                            setState(() {
                              cidadeSelecionada = selecao;
                            });
                          },

                          fieldViewBuilder: (
                              BuildContext context,
                              TextEditingController fieldController,
                              FocusNode fieldFocusNode,
                              VoidCallback onFieldSubmitted,
                              ) {

                            // Mantém o controller interno do Autocomplete em
                            // sincronia com o nosso, e vice-versa, para que o
                            // clear() feito ao trocar o Estado também limpe
                            // o que está visível no campo de texto.
                            cidadeBuscaController.value = fieldController.value;

                            fieldController.addListener(() {
                              if (fieldController.text != cidadeSelecionada) {
                                // Usuário está digitando algo diferente do que
                                // tinha selecionado antes: invalida a seleção
                                // até que ele escolha uma opção da lista de novo.
                                if (cidadeSelecionada != null &&
                                    fieldController.text != cidadeSelecionada) {
                                  setState(() {
                                    cidadeSelecionada = null;
                                  });
                                }
                              }
                            });

                            return TextFormField(

                              controller: fieldController,

                              focusNode: fieldFocusNode,

                              enabled: cidades.isNotEmpty,

                              decoration: InputDecoration(

                                labelText: cidades.isEmpty
                                    ? 'Selecione um estado primeiro'
                                    : 'Cidade',

                                errorText:
                                cidadeInvalida

                                    ? 'Selecione uma cidade'
                                    : null,

                                enabledBorder:
                                OutlineInputBorder(

                                  borderRadius:
                                  BorderRadius.circular(10),

                                  borderSide:
                                  BorderSide(

                                    color:
                                    cidadeInvalida

                                        ? Colors.red
                                        : Colors.grey,
                                  ),
                                ),

                                focusedBorder:
                                OutlineInputBorder(

                                  borderRadius:
                                  BorderRadius.circular(10),

                                  borderSide:
                                  BorderSide(

                                    color:
                                    cidadeInvalida

                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                              ),
                            );
                          },

                          optionsViewBuilder: (
                              BuildContext context,
                              AutocompleteOnSelected<String> onSelected,
                              Iterable<String> options,
                              ) {

                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(10),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 220,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                        title: Text(option),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      SizedBox(

                        width: double.infinity,

                        child: ElevatedButton(

                          onPressed: isRegistering

                              ? null

                              : () async {

                            setState(() {

                              tentouCadastrar =
                              true;
                            });

                            if (

                            nomeInvalido ||
                                emailInvalido ||
                                senhaInvalida ||
                                confirmaSenhaInvalida ||
                                estadoInvalido ||
                                cidadeInvalida
                            ) {
                              return;
                            }

                            setState(() {
                              isRegistering = true;
                            });

                            final authService =
                            AuthService();

                            final erro =

                            await authService
                                .cadastrarUsuario(

                              nome:
                              nomeController.text,

                              email:
                              emailController.text,

                              senha:
                              senhaController.text,

                              estado:
                              estadoSelecionado ?? '',

                              cidade:
                              cidadeSelecionada ?? '',
                            );

                            if (!mounted) return;

                            setState(() {
                              isRegistering = false;
                            });

                            if (erro == null) {

                              // 🔁 VOLTAR AO LOGIN
                              // Navega primeiro, e mostra o SnackBar de
                              // sucesso já no contexto da LoginPage —
                              // assim a transição não compete com o
                              // tempo de exibição do SnackBar na tela
                              // de Cadastro, que está sendo removida.
                              Navigator.pushAndRemoveUntil(

                                context,

                                AppPageRoute(
                                  builder: (_) => LoginPage(),
                                  transition: AppTransition.fade,
                                ),

                                    (route) => false,
                              );

                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(

                                const SnackBar(

                                  content: Text(
                                    'Cadastro criado com sucesso',
                                  ),
                                ),
                              );

                            } else {

                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(

                                SnackBar(
                                  content:
                                  Text(erro),
                                ),
                              );
                            }
                          },

                          child: isRegistering

                              ? const SizedBox(

                            width: 20,
                            height: 20,

                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )

                              : const Text(
                            "Realizar Cadastro",
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      TextButton.icon(

                        onPressed: () {

                          Navigator.pop(context);
                        },

                        icon: const Icon(

                          Icons.keyboard_arrow_down,

                          color: AppColors.background,
                        ),

                        label: const Text(

                          'Voltar para login',

                          style: TextStyle(

                            color: AppColors.background,

                            fontWeight:
                            FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🧱 CAMPO PADRÃO
  // Constrói um TextFormField padronizado, com suporte a
  // campo de senha (ícone de olho para mostrar/ocultar) e a
  // exibição de erro de validação.
  Widget buildField(
      String label,
      TextEditingController controller, {

        bool isPassword = false,

        bool mostrarSenha = false,

        bool error = false,

        VoidCallback? onTogglePassword,
      }) {

    return Padding(

      padding: const EdgeInsets.only(
        bottom: AppSpacing.md,
      ),

      child: TextFormField(

        controller: controller,

        obscureText:
        isPassword && !mostrarSenha,

        // Reconstrói a tela a cada tecla digitada para que os
        // getters de validação (que leem controller.text) reavaliem
        // e a mensagem de erro suma assim que o campo for corrigido,
        // sem esperar por outro rebuild (ex: alternar visibilidade
        // da senha).
        onChanged: (_) {
          setState(() {});
        },

        decoration: InputDecoration(

          labelText: label,

          errorText: error
              ? 'Campo inválido'
              : null,

          enabledBorder: OutlineInputBorder(

            borderRadius:
            BorderRadius.circular(10),

            borderSide: BorderSide(

              color: error
                  ? Colors.red
                  : Colors.grey,
            ),
          ),

          focusedBorder: OutlineInputBorder(

            borderRadius:
            BorderRadius.circular(10),

            borderSide: BorderSide(

              color: error
                  ? Colors.red
                  : Colors.green,
            ),
          ),

          // 👁️ MOSTRAR/OCULTAR SENHA
          // Só exibe o ícone de olho quando o campo for de senha.
          suffixIcon: isPassword
              ? IconButton(

            icon: Icon(

              mostrarSenha
                  ? Icons.visibility
                  : Icons.visibility_off,
            ),

            onPressed: onTogglePassword,
          )
              : null,
        ),
      ),
    );
  }
}