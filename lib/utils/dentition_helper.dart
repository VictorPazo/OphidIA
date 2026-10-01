String? dentitionImageAsset(String dentitionType) {

  final normalized = dentitionType
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('ó', 'o')
      .trim();

  switch (normalized) {
    case 'aglifa':
      return 'assets/dentition/aglifa.png';
    case 'opistoglifa':
      return 'assets/dentition/opistoglifa.png';
    case 'proteroglifa':
      return 'assets/dentition/proteroglifa.png';
    case 'solenoglifa':
      return 'assets/dentition/solenoglifa.png';
    default:
      return null;
  }
}

/// `dentition_type` vem do banco como um dos ~4 valores fixos em português
/// (Áglifa, Opistóglifa, Proteróglifa, Solenóglifa) — por ser um enum
/// pequeno e estável, é traduzido com chaves estáticas do easy_localization
/// em vez de ganhar uma coluna `_en`. Devolve a chave pronta para `.tr()`;
/// se o valor não for reconhecido (ex: "REVISAR"), devolve o próprio valor
/// como fallback, e `.tr()` nesse caso simplesmente ecoa o texto original.
String dentitionTranslationKey(String dentitionType) {

  final normalized = dentitionType
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('ó', 'o')
      .trim();

  switch (normalized) {
    case 'aglifa':
      return 'dentition_aglifa';
    case 'opistoglifa':
      return 'dentition_opistoglifa';
    case 'proteroglifa':
      return 'dentition_proteroglifa';
    case 'solenoglifa':
      return 'dentition_solenoglifa';
    default:
      return dentitionType;
  }
}