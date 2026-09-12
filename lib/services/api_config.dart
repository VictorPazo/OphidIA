/// Endereço do servidor FastAPI de `lib/models` (endpoints /predict e
/// /detect).
///
/// Fica isolado aqui porque o IAService e o YoloService falam com o MESMO
/// servidor. Duplicar o endereço nos dois arquivos fazia com que trocar de
/// máquina exigisse editar dois lugares, e esquecer um deles quebrava só
/// metade do fluxo, de um jeito difícil de perceber.
///
/// **Fica vazio no repositório de propósito.** Endereço de servidor é
/// configuração de cada máquina, não código: versionar o IP de alguém faz o
/// app quebrar para todo mundo na próxima vez que a rede mudar. Preencha
/// localmente e não commite o valor.
///
/// Valor por cenário:
///
///   Celular por cabo USB   'http://localhost:8000'
///                          junto de: adb reverse tcp:8000 tcp:8000
///
///   Emulador Android       'http://10.0.2.2:8000'
///                          (o IP da rede local NÃO funciona no emulador)
///
///   Celular no Wi-Fi       'http://SEU_IP:8000'
///                          descubra com `ipconfig` / `ip addr`
///
///   Servidor hospedado     'https://seu-dominio'
///                          o Android bloqueia http sem TLS, então precisa
///                          ser https
class ApiConfig {

  const ApiConfig._();

  static const String baseUrl =
      'https://zyiihfeqpcvcidnolbymsji3hy0ijjfq.lambda-url.sa-east-1.on.aws';
}
