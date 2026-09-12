# Servidor de inferência no AWS Lambda

Coloca o `main.py` na nuvem com endereço HTTPS fixo, para o app funcionar fora
de casa sem depender do PC nem de cabo.

Custo esperado: **praticamente zero**. O nível gratuito permanente do Lambda
(1 milhão de requisições e 400 mil GB-segundo por mês) cobre com folga o volume
de um TCC.

---

## Antes de começar

Instale os dois, que não estão na máquina:

- **Docker Desktop** — <https://www.docker.com/products/docker-desktop/>
  Reinicie o Windows depois e confirme que a baleia aparece na bandeja.
- **AWS CLI** — <https://aws.amazon.com/cli/>

Crie uma conta na AWS e, no IAM, um usuário com acesso programático e as
políticas `AmazonEC2ContainerRegistryFullAccess` e `AWSLambda_FullAccess`.
Depois:

```powershell
aws configure
```

Informe a chave, o segredo e a região. Use **`sa-east-1`** (São Paulo): fica
mais perto e reduz a latência de cada identificação.

---

## 1. Criar o repositório de imagens

```powershell
aws ecr create-repository --repository-name ophidia --region sa-east-1
```

Anote o `repositoryUri` que ele devolve. Tem o formato
`<ID-DA-CONTA>.dkr.ecr.sa-east-1.amazonaws.com/ophidia`.

## 2. Construir a imagem

```powershell
cd "D:\Nova pasta\snakes_of_imt\lib\models"
docker build -t ophidia .
```

A primeira construção demora, porque baixa o PyTorch e os 107 MB do
classificador. O `Dockerfile` busca o classificador direto do release do
GitHub e confere o tamanho, então não depende do arquivo estar no seu disco.

## 3. Publicar no ECR

```powershell
$conta = (aws sts get-caller-identity --query Account --output text)
$uri = "$conta.dkr.ecr.sa-east-1.amazonaws.com/ophidia"

aws ecr get-login-password --region sa-east-1 | docker login --username AWS --password-stdin $uri

docker tag ophidia:latest "$uri`:latest"
docker push "$uri`:latest"
```

## 4. Criar a função

No console do Lambda, **Create function > Container image**:

| Campo | Valor |
|---|---|
| Nome | `ophidia` |
| Imagem | a que você acabou de publicar |
| Arquitetura | `x86_64` |

Depois, em **Configuration > General configuration**, ajuste:

| Ajuste | Valor | Por quê |
|---|---|---|
| Memory | **4096 MB** | O processo usa ~1,6 GB, mas no Lambda a CPU é proporcional à memória. Mais memória deixa a inferência e a partida a frio bem mais rápidas, e como se paga por GB-segundo, terminar antes compensa boa parte do custo. |
| Timeout | **60 s** | A primeira invocação carrega os dois modelos. O padrão de 3 s falharia sempre. |
| Ephemeral storage | 512 MB | O padrão basta. |

## 5. Criar o endereço público

Em **Configuration > Function URL > Create function URL**:

- Auth type: **NONE** (o app não tem credencial da AWS)
- CORS: pode deixar desligado, o app Flutter não é navegador

Ele devolve uma URL como
`https://abc123xyz.lambda-url.sa-east-1.on.aws/`.

Teste no navegador acrescentando `/docs`. Se a página do FastAPI abrir, está
funcionando — a primeira tentativa pode levar uns 30 segundos.

## 6. Apontar o app

Em `lib/services/api_config.dart`, sem a barra no fim:

```dart
static const String baseUrl = 'https://abc123xyz.lambda-url.sa-east-1.on.aws';
```

Remova também `android:usesCleartextTraffic="true"` do
`android/app/src/main/AndroidManifest.xml`: ele só existia para permitir o
servidor local em HTTP, e agora tudo é HTTPS.

Gere o APK:

```powershell
flutter build apk --release --split-per-abi
```

O arquivo é `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

---

## A partida a frio

É o ponto fraco desta arquitetura e vale conhecer antes da banca.

Depois de alguns minutos sem uso, a AWS desliga o ambiente. A próxima
requisição precisa carregar o PyTorch e os dois modelos de novo, o que leva de
**10 a 25 segundos**. As seguintes respondem normalmente.

Duas formas de evitar isso numa apresentação:

**Aquecer antes.** Abra a URL no navegador cinco minutos antes de começar. O
ambiente fica quente por volta de 10 a 15 minutos sem uso.

**Manter aquecido.** Uma regra do EventBridge chamando a função a cada 5
minutos resolve de vez. Consome do nível gratuito, mas cabe: são cerca de 8.600
invocações por mês, contra o limite de 1 milhão.

---

## Limites que importam

**6 MB por requisição.** É o teto do Lambda para o corpo da chamada. A foto da
câmera não chega perto, porque sai em resolução média. As da galeria passavam
disso antes — por isso o `pickImage` agora reduz para 1600 px de largura e 85%
de qualidade, o que não custa precisão nenhuma, já que o classificador
redimensiona tudo para 384 px de qualquer forma.

**Imagem de até 10 GB.** A nossa fica em torno de 2 GB, então sobra espaço.

---

## Usar o ophidia.com.br

A Function URL já é HTTPS e estável, e serve perfeitamente para o APK. O
domínio próprio é um passo opcional e posterior.

Para ligá-lo, o caminho é criar uma distribuição do **CloudFront** apontando
para a Function URL, pedir um certificado gratuito no **ACM** (precisa ser na
região `us-east-1`, é exigência do CloudFront) e criar um registro CNAME no
Registro.br apontando `api.ophidia.com.br` para o endereço do CloudFront.

Vale fazer depois que o fluxo estiver funcionando pela Function URL — assim, se
algo falhar, você sabe que o problema é o domínio e não o servidor.
