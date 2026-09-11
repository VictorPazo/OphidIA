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