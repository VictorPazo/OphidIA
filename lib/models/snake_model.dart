class SnakeModel {

  final int id;

  final String family;

  final String genus;

  final String specie;

  final String? popularNamePt;

  final String? popularNameEn;

  final String? description;

  final String? descriptionEn;

  final bool poisonous;

  final String dentition_type;

  final String venomType;

  final String? venomTypeEn;

  final String? effectiveAntivenom;

  final String? effectiveAntivenomEn;

  final String imageName;

  SnakeModel({

    required this.id,

    required this.family,

    required this.genus,

    required this.specie,

    this.popularNamePt,

    this.popularNameEn,

    this.description,

    this.descriptionEn,

    required this.poisonous,

    required this.dentition_type,

    required this.venomType,

    this.venomTypeEn,

    this.effectiveAntivenom,

    this.effectiveAntivenomEn,

    required this.imageName,
  });

  factory SnakeModel.fromMap(
      Map<String, dynamic> map,
      ) {

    return SnakeModel(

      id: map['id'],

      family: map['family'],

      genus: map['genus'],

      specie: map['specie'],

      popularNamePt: map['popular_name_pt'],

      popularNameEn: map['popular_name_en'],

      description: map['description'],

      descriptionEn: map['description_en'],

      poisonous: map['poisonous'],

      dentition_type: map['dentition_type'],

      venomType: map['venom_type'],

      venomTypeEn: map['venom_type_en'],

      effectiveAntivenom:
      map['effective_antivenom'],

      effectiveAntivenomEn: map['effective_antivenom_en'],

      imageName: map['image_name'],
    );
  }

  // Marcador usado pelo pipeline de curadoria (lib/scripts/enrich.py e a
  // migração 0001) para campos _en ainda não traduzidos/revisados.
  static const _pendingReview = 'REVISAR';

  static bool _isCurated(String? value) =>
      value != null &&
      value.trim().isNotEmpty &&
      value.trim().toUpperCase() != _pendingReview;

  // Usa o campo _en quando o idioma ativo é inglês e ele já foi curado;
  // caso contrário cai para o campo em português — o mesmo comportamento de
  // fallback que o easy_localization já usa no resto do app (fallbackLocale
  // pt-BR), em vez de expor "REVISAR" na tela.
  String? _localized(String languageCode, String? ptValue, String? enValue) {
    if (languageCode == 'en' && _isCurated(enValue)) return enValue;
    return ptValue;
  }

  /// Todos os nomes populares cadastrados, separados por vírgula.
  ///
  /// Uma espécie costuma ter nome diferente em cada região, e quem procura
  /// pelo nome da sua região precisa encontrá-la. É este campo inteiro que a
  /// busca do catálogo varre.
  String? localizedPopularName(String languageCode) {
    final value = _localized(languageCode, popularNamePt, popularNameEn);
    return _isCurated(value) ? value : null;
  }

  /// Só o primeiro nome da lista, que é o que aparece na tela.
  ///
  /// O título da ficha e o cartão do catálogo têm espaço para um nome, não
  /// para uma lista: `maxLines: 1` cortaria as variantes no meio de uma
  /// palavra. A convenção é escrever o nome mais conhecido primeiro no
  /// cadastro, e os regionais depois dele.
  String? localizedPopularNameMain(String languageCode) {
    final completo = localizedPopularName(languageCode);
    if (completo == null) return null;

    final primeiro = completo.split(',').first.trim();
    return primeiro.isEmpty ? null : primeiro;
  }

  String? localizedDescription(String languageCode) =>
      _localized(languageCode, description, descriptionEn);

  String localizedVenomType(String languageCode) =>
      _localized(languageCode, venomType, venomTypeEn) ?? venomType;

  String? localizedEffectiveAntivenom(String languageCode) =>
      _localized(languageCode, effectiveAntivenom, effectiveAntivenomEn);
}
