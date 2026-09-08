# Setup — rodando o OphidIA em outra máquina

Passo a passo do clone até a primeira identificação. O projeto tem duas metades que
sobem separadamente: o **app Flutter** e o **servidor de inferência FastAPI**. As duas
precisam estar no ar ao mesmo tempo, e o app precisa saber o IP do servidor.

## Pré-requisitos

| Ferramenta | Versão | Observação |
|---|---|---|
| Flutter + Android SDK | 3.41.9 (testada) | `flutter doctor` deve passar |
| Python | 3.12 | no Windows, os comandos abaixo usam `py -3.12` |
| Dispositivo Android | físico ou emulador | o físico precisa estar no mesmo Wi-Fi do servidor |

> As constraints do `pubspec.yaml` foram afrouxadas para caber no Flutter 3.41.9
> (`shimmer ^3.0.0`, `flutter_native_splash ^2.4.0`). Em um Flutter mais novo elas
> continuam resolvendo, só não pegam as versões mais recentes desses dois pacotes.

## 1. Dependências do app

```bash
flutter pub get
```

## 2. Dependências do servidor de inferência

```bash
cd lib/models
pip install -r requirements.txt
```

Isso instala a build de **CPU** do PyTorch, que funciona normalmente (só mais lenta:
~83 ms por imagem contra ~10 ms em GPU). Para GPU:

```bash
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130
```

## 3. Baixar os pesos do modelo

O arquivo `lib/models/best_model.pth` tem 107 MB — acima do limite de 100 MB por arquivo
do GitHub. Por isso `*.pth` está no `.gitignore` e **o modelo não vem no clone**: ele é
distribuído como anexo de *release*. Sem esse arquivo o `uvicorn` nem sobe.

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

### Conferir o download

O arquivo tem exatamente **112.104.519 bytes** e o hash abaixo, que é o mesmo exibido na
página do release:

```
sha256  9889bf699834bd70b996a52e8454f3aba34879c8ba9dfa5345ac17646dcc4c98
```

```powershell
(Get-FileHash lib\models\best_model.pth -Algorithm SHA256).Hash
```

```bash
sha256sum lib/models/best_model.pth
```

### O modelo e o `classes.json` são um par

O `lib/models/classes.json` (246 espécies) **está** versionado e já vem no clone. Ele
traduz o índice que a rede devolve para o nome da espécie, então os dois arquivos têm que
vir do mesmo treino — senão as predições saem trocadas **sem gerar erro nenhum**.

A descrição de cada release diz com qual commit ele pareia. O `ModeloConvNeXt-Tiny_v2`
corresponde ao `classes.json` do commit `3cacdf1`.

## 4. Subir o servidor

```bash
cd lib/models
py -3.12 -m uvicorn main:app --host 0.0.0.0 --port 8000
```

O `--host 0.0.0.0` não é opcional — sem ele o servidor só aceita conexões do próprio PC e
o celular não alcança. Na primeira execução o Windows pode pedir liberação no firewall:
aceite para rede **privada**.

Para conferir se subiu, do próprio PC: <http://localhost:8000/docs>

## 5. Apontar o app para o servidor

Edite `baseUrl` em `lib/services/agent_service.dart`:

- **Celular físico** — o IP da máquina na rede local (`ipconfig` no Windows,
  `ip addr` no Linux). Ex.: `http://192.168.0.2:8000`
- **Emulador Android** — obrigatoriamente `http://10.0.2.2:8000`. O IP da LAN **não**
  funciona no emulador; `10.0.2.2` é como ele enxerga o PC hospedeiro.

## 6. Rodar o app

```bash
flutter run
```

## Opcional — pipeline de povoamento do banco

Só é necessário para inserir novas espécies na tabela `snakes` do Supabase. O passo a
passo completo está em [`lib/scripts/README.md`](lib/scripts/README.md).

```bash
cd lib/scripts
pip install -r requirements.txt
```

Exige um arquivo `.env` (também **não versionado**) nesta pasta:

```
SUPABASE_URL=...
SUPABASE_SERVICE_KEY=...
```

A `service_role` key sai em *Project Settings > API > service_role secret* no painel do
Supabase.

## O que NÃO precisa ser configurado

- **Supabase do app** — URL e anon key estão fixos em `lib/main.dart`.
- **Google Maps** — a chave já está no `android/app/src/main/AndroidManifest.xml`.

## Resumo: o que não vem no clone

| Arquivo | Como obter |
|---|---|
| `lib/models/best_model.pth` | baixar do [release `ModeloConvNeXt-Tiny_v2`](https://github.com/VictorPazo/OphidIA/releases/download/ModeloConvNeXt-Tiny_v2/best_model.pth) (107 MB, fora do git) — passo 3 |
| `lib/scripts/.env` | criar à mão com as credenciais do Supabase |
