# Setup: rodando o OphidIA em outra máquina

Passo a passo do clone até a primeira identificação.

O servidor de inferência roda na **AWS Lambda**, e o app já aponta para ele. Para
desenvolver o app basta o Flutter e um Android: **não é preciso Python, modelo nem
servidor no computador**. O servidor local só interessa a quem for mexer no modelo ou na
API, e está no fim deste guia, como opcional.

## Pré-requisitos

| Ferramenta | Versão | Observação |
|---|---|---|
| Flutter + Android SDK | 3.41.9 (testada) | `flutter doctor` deve passar |
| Dispositivo Android | físico ou emulador | físico com depuração USB ativada; emulador com imagem *Google Play*, senão o mapa não carrega |
| Internet | | o app consulta a Lambda e o Supabase |

> As constraints do `pubspec.yaml` foram afrouxadas para caber no Flutter 3.41.9
> (`shimmer ^3.0.0`, `flutter_native_splash ^2.4.0`). Em um Flutter mais novo elas
> continuam resolvendo, só não pegam as versões mais recentes desses dois pacotes.

Só Android foi testado. O build para iPhone exige um Mac com Xcode.

## 1. Clonar e instalar

```bash
git clone https://github.com/VictorPazo/OphidIA.git
cd OphidIA
flutter pub get
```

## 2. Rodar

Com o celular conectado por USB (ou o emulador aberto):

```bash
flutter devices
flutter run
```

Pronto. A câmera, a identificação, o catálogo e o mapa funcionam sem mais nada.

Se a primeira identificação do dia demorar até uns 30 segundos, é o servidor acordando.
Uma regra do EventBridge chama a Lambda a cada 5 minutos para mantê-la acordada, então
isso deve ser raro (detalhes em [`lib/models/DEPLOY-LAMBDA.md`](lib/models/DEPLOY-LAMBDA.md)).

## O que já vem configurado

| O quê | Onde |
|---|---|
| Endereço do servidor (Lambda) | `lib/services/api_config.dart` |
| Supabase do app (URL e anon key) | `lib/main.dart` |
| Chave do Google Maps | `android/app/src/main/AndroidManifest.xml` |
| Lista das 246 espécies que o modelo reconhece | `lib/models/classes.json` (usada pelo catálogo) |

## O que não vem no clone

| Arquivo | Para quê | Como obter |
|---|---|---|
| `lib/scripts/.env` | só para os scripts de dados (opcional B) | pedir a quem administra o Supabase; contém a chave de serviço e **não pode ir para o git** |
| `lib/models/best_model.pth` | só para o servidor local (opcional A) | baixar do release, ver abaixo |

---

## Opcional A: servidor de inferência local

Só para quem for treinar, trocar ou depurar o modelo, ou mudar a API. Exige Python 3.12.

### Dependências

```bash
cd lib/models
pip install -r requirements.txt
```

Isso instala a build de **CPU** do PyTorch, que funciona normalmente (só mais lenta:
~83 ms por imagem contra ~10 ms em GPU). Para GPU:

```bash
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130
```

### Baixar os pesos do modelo

O `best_model.pth` tem 107 MB, acima do limite de 100 MB por arquivo do GitHub. Por isso
`*.pth` está no `.gitignore` e o modelo é distribuído como anexo de *release*. Sem ele o
`uvicorn` nem sobe.

A partir da raiz do repositório:

**Windows (PowerShell)**

```powershell
Invoke-WebRequest -Uri "https://github.com/VictorPazo/OphidIA/releases/download/ModeloConvNeXt-Tiny_v2/best_model.pth" -OutFile "lib\models\best_model.pth"
```

**Linux / macOS**

```bash
curl -L -o lib/models/best_model.pth \
  https://github.com/VictorPazo/OphidIA/releases/download/ModeloConvNeXt-Tiny_v2/best_model.pth
```

O `-L` do curl não é opcional: o GitHub responde com um redirecionamento para a CDN e,
sem ele, você baixa um arquivo vazio.

Para conferir: o arquivo tem exatamente **112.104.519 bytes** e este SHA-256, o mesmo da
página do release:

```
9889bf699834bd70b996a52e8454f3aba34879c8ba9dfa5345ac17646dcc4c98
```

```powershell
(Get-FileHash lib\models\best_model.pth -Algorithm SHA256).Hash
```

```bash
sha256sum lib/models/best_model.pth
```

**O modelo e o `classes.json` são um par.** O `classes.json` traduz o índice que a rede
devolve para o nome da espécie, então os dois têm que vir do mesmo treino; senão as
predições saem trocadas **sem gerar erro nenhum**. O `ModeloConvNeXt-Tiny_v2` corresponde
ao `classes.json` do commit `3cacdf1`. Ao trocar o modelo, troque os dois juntos, e
lembre que o catálogo do app também lê esse arquivo.

### Subir o servidor

```bash
cd lib/models
py -3.12 -m uvicorn main:app --host 0.0.0.0 --port 8000
```

O `--host 0.0.0.0` é obrigatório: sem ele o servidor só aceita conexões do próprio PC e o
celular não alcança. Na primeira execução o Windows pode pedir liberação no firewall;
aceite para rede **privada**. Para conferir, do próprio PC: <http://localhost:8000/docs>

### Apontar o app para o servidor local

Troque o `baseUrl` em `lib/services/api_config.dart`:

- **Celular físico**: o IP do computador na rede local, com celular e PC no mesmo Wi-Fi
  (`ipconfig` no Windows, `ip addr` no Linux). Ex.: `http://192.168.0.2:8000`
- **Emulador Android**: obrigatoriamente `http://10.0.2.2:8000`, que é como o emulador
  enxerga o computador hospedeiro.

O servidor local fala `http`, sem HTTPS, e isso só é aceito no modo de depuração
(`flutter run`), liberado em `android/app/src/debug/AndroidManifest.xml`. Um APK de
release recusa a conexão.

> **Antes de commitar ou gerar APK, volte o `baseUrl` para o endereço da Lambda.**
> Um APK que aponta para um IP local carrega para sempre fora daquela rede, sem mensagem
> de erro, e já aconteceu neste projeto.

### Publicar o servidor na Lambda

O passo a passo de construir a imagem, enviar ao ECR e atualizar a função está em
[`lib/models/DEPLOY-LAMBDA.md`](lib/models/DEPLOY-LAMBDA.md).

---

## Opcional B: scripts de dados

Para inserir espécies na tabela `snakes` do Supabase ou atualizar dados em massa
(nomes populares, dentição). O passo a passo do povoamento está em
[`lib/scripts/README.md`](lib/scripts/README.md).

```bash
cd lib/scripts
pip install -r requirements.txt
```

Exige o `lib/scripts/.env`, que não vem no clone:

```
SUPABASE_URL=...
SUPABASE_SERVICE_KEY=...
```

A chave de serviço dá acesso total ao banco. Nunca a coloque no app nem no git.

Os scripts que gravam em massa (`apply_popular_names.py`, `apply_denticao.py`) rodam em
**simulação** por padrão e só gravam com `--gravar`. Confira a simulação antes.

---

## Gerar o APK para distribuir

```bash
flutter build apk --release --split-per-abi
```

Distribua o `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, que serve para
qualquer Android dos últimos anos. Antes de gerar, suba o `version` no `pubspec.yaml`.

Dois cuidados:

- **Gere sempre na mesma máquina.** O release é assinado com a chave de depuração local
  (`~/.android/debug.keystore`). Um APK gerado em outro computador tem outra assinatura,
  e quem já tem o app instalado não consegue atualizar sem desinstalar.
- **Não distribua o `app-release.apk` universal junto com o dividido.** Os dois têm
  `versionCode` diferentes, e alternar entre eles faz o Android recusar a instalação
  como rebaixamento de versão.
