import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/password_rules.dart';

class AuthService {

  final supabase = Supabase.instance.client;

  // A regra vive em PasswordRules para o formulário de cadastro mostrar ao
  // vivo exatamente o que este serviço vai cobrar. Antes eram duas regras
  // diferentes, e a tela aceitava senha que o serviço recusava.
  bool senhaForte(String senha) => PasswordRules.isStrong(senha);

  Future<String?> cadastrarUsuario({
    required String nome,
    required String email,
    required String senha,
    required String estado,
    required String cidade,
  }) async {

    try {
      if (!senhaForte(senha)) {
        return
          'A senha deve conter:\n'
              '- mínimo 8 caracteres\n'
              '- letra maiúscula\n'
              '- letra minúscula\n'
              '- número\n'
              '- caractere especial';
      }

      final existente = await supabase
          .from('profiles')
          .select('id')
          .eq('mail', email.trim().toLowerCase())
          .maybeSingle();

      if (existente != null) {
        return 'Email já está cadastrado. Faça login!';
      }

      final AuthResponse response =
      await supabase.auth.signUp(
        email: email,
        password: senha,
        data: {
          'nome': nome,
          'estado': estado,
          'cidade': cidade,
        },
      );

      final user = response.user;

      if (user == null) {
        return 'Erro ao criar usuário';
      }

      return null;

    } catch (e) {

      if (e is AuthException) {

        switch (e.message) {

          case 'User already registered':
            return 'Este email já está cadastrado. Faça login.';

          default:
            return 'Erro ao cadastrar usuário';
        }
      }

      return 'Erro inesperado! Será implementado em atualizações futuras';
    }

  }

  Future<String?> login({
    required String email,
    required String senha,
  }) async {

    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: senha,
      );

      return null;

    } catch (e) {

      if (e is AuthException) {

        switch (e.message) {

          case 'Invalid login credentials':
            return 'Email ou senha inválidos';

          case 'Email not confirmed':
            return 'Confirme seu email antes de entrar';

          default:
            return 'Erro de autenticação';
        }
      }

      return 'Erro inesperado! Será implementado em atualizações futuras';
    }
  }

}