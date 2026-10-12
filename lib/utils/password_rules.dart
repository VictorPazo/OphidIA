/// Regras de senha forte, em um lugar só.
///
/// Antes a regra existia duas vezes e com valores diferentes: o formulário de
/// cadastro aceitava 6 caracteres, enquanto o `AuthService` exigia 8 com
/// maiúscula, minúscula, número e especial. A pessoa preenchia, enviava, e só
/// então recebia a lista de requisitos — depois de a tela já ter sido validada
/// como correta.
///
/// Com as checagens aqui, o formulário mostra ao vivo exatamente o que o
/// serviço vai cobrar, e as duas nunca mais divergem.
class PasswordRules {

  const PasswordRules._();

  static const int minLength = 8;

  static bool hasMinLength(String s) => s.length >= minLength;

  static bool hasUpper(String s) => RegExp(r'[A-Z]').hasMatch(s);

  static bool hasLower(String s) => RegExp(r'[a-z]').hasMatch(s);

  static bool hasDigit(String s) => RegExp(r'\d').hasMatch(s);

  /// Qualquer coisa que não seja letra nem dígito. Mantido amplo de propósito:
  /// restringir a uma lista fechada de símbolos só frustra quem usa um
  /// gerenciador de senhas.
  static bool hasSpecial(String s) => RegExp(r'[^A-Za-z0-9]').hasMatch(s);

  static bool isStrong(String s) =>
      hasMinLength(s) &&
      hasUpper(s) &&
      hasLower(s) &&
      hasDigit(s) &&
      hasSpecial(s);

  /// As cinco checagens com a chave de tradução de cada uma, na ordem em que
  /// aparecem na tela.
  static List<({String key, bool Function(String) check})> get all => [
        (key: 'password_rule_length', check: hasMinLength),
        (key: 'password_rule_upper', check: hasUpper),
        (key: 'password_rule_lower', check: hasLower),
        (key: 'password_rule_digit', check: hasDigit),
        (key: 'password_rule_special', check: hasSpecial),
      ];
}
